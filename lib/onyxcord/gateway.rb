# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'async/http/protocol/http11'
require 'async/websocket/client'
require 'onyxcord/async/runtime'
require 'onyxcord/rate_limiter/gateway'

module OnyxCord
  # Gateway packet opcodes
  module Opcodes
    DISPATCH = 0
    HEARTBEAT = 1
    IDENTIFY = 2
    PRESENCE = 3
    VOICE_STATE = 4
    VOICE_PING = 5
    RESUME = 6
    RECONNECT = 7
    REQUEST_MEMBERS = 8
    INVALIDATE_SESSION = 9
    HELLO = 10
    HEARTBEAT_ACK = 11
  end

  # Stores data of an active gateway session.
  class Session
    attr_reader :session_id, :resume_gateway_url
    attr_accessor :sequence

    def initialize(session_id, resume_gateway_url)
      @session_id = session_id
      @sequence = 0
      @suspended = false
      @invalid = false
      @resume_gateway_url = resume_gateway_url
    end

    def suspend
      @suspended = true
    end

    def suspended?
      @suspended
    end

    def resume
      @suspended = false
    end

    def invalidate
      @invalid = true
      @resume_gateway_url = nil
    end

    def invalid?
      @invalid
    end

    def should_resume?
      suspended? && !invalid?
    end
  end

  # Client for the Discord gateway protocol — fully async.
  class Gateway
    LARGE_THRESHOLD = 100
    GATEWAY_VERSION = 9
    FATAL_CLOSE_CODES = [4003, 4004, 4011, 4014].freeze

    attr_accessor :check_heartbeat_acks
    attr_reader :intents

    def initialize(bot, token, shard_key = nil, compress_mode = :stream, intents = ALL_INTENTS)
      @token = token
      @bot = bot
      @shard_key = shard_key
      @ws_success = false
      @check_heartbeat_acks = true
      @compress_mode = compress_mode
      @intents = intents
      @send_limiter = OnyxCord::RateLimiter::Gateway.new
      @connection = nil
      @closed = true
      @pipe_broken = false
      @missed_heartbeat_acks = 0
    end

    # Connect to the gateway server inside an Async reactor.
    def run_async
      @task = OnyxCord::AsyncRuntime.async { run }

      LOGGER.debug('Gateway task created! Waiting for confirmation...')
      loop do
        OnyxCord::AsyncRuntime.sleep(0.5)
        break if @ws_success
        break if @should_reconnect == false
      end
    end

    def run
      @reactor_task = Async::Task.current
      connect_loop
      LOGGER.warn('The gateway loop exited!')
    end

    def sync
      @task&.wait
    end

    def open?
      !@closed && @connection
    end

    def stop
      @should_reconnect = false
      close
      nil
    end

    def kill
      @task&.stop
    end

    def notify_ready
      @ws_success = true
    end

    def inject_reconnect(url = nil)
      data = url ? { url: url } : nil
      handle_message({ op: Opcodes::RECONNECT, d: data }.to_json)
    end

    def inject_resume(seq)
      send_resume(raw_token, @session_id, seq || @sequence)
    end

    def inject_error(e)
      handle_internal_close(e)
    end

    def heartbeat
      if check_heartbeat_acks
        unless @last_heartbeat_acked
          @missed_heartbeat_acks += 1
          if @missed_heartbeat_acks >= 2
            LOGGER.warn('Last heartbeats were not acked — zombie connection! Reconnecting')
            @pipe_broken = true
            reconnect
            return
          end

          LOGGER.warn('Last heartbeat was not acked — waiting one more interval before reconnecting')
        else
          @missed_heartbeat_acks = 0
        end
        @last_heartbeat_acked = false
      end
      send_heartbeat(@session ? @session.sequence : 0)
    end

    def send_heartbeat(sequence)
      send_packet(Opcodes::HEARTBEAT, sequence)
    end

    def identify
      compress = @compress_mode == :large
      send_identify(@token, {
                      os: RUBY_PLATFORM,
                      browser: 'onyxcord',
                      device: 'onyxcord'
                    }, compress, LARGE_THRESHOLD, @shard_key, @intents)
    end

    def send_identify(token, properties, compress, large_threshold, shard_key = nil, intents = ALL_INTENTS)
      data = {
        token: token,
        properties: properties,
        compress: compress,
        large_threshold: large_threshold,
        intents: intents
      }
      data[:shard] = shard_key if shard_key
      send_packet(Opcodes::IDENTIFY, data)
    end

    def send_status_update(status, since, game, afk)
      send_packet(Opcodes::PRESENCE, { status: status, since: since, game: game, afk: afk })
    end

    def send_voice_state_update(server_id, channel_id, self_mute, self_deaf)
      send_packet(Opcodes::VOICE_STATE, {
                    guild_id: server_id, channel_id: channel_id,
                    self_mute: self_mute, self_deaf: self_deaf
                  })
    end

    def resume
      send_resume(@token, @session.session_id, @session.sequence)
    end

    def reconnect(attempt_resume = true)
      @session.suspend if @session && attempt_resume
      @instant_reconnect = true
      @should_reconnect = true
      close(4000)
    end

    def send_resume(token, session_id, seq)
      send_packet(Opcodes::RESUME, { token: token, session_id: session_id, seq: seq })
    end

    def send_request_members(server_id, query, limit)
      send_packet(Opcodes::REQUEST_MEMBERS, { guild_id: server_id, query: query, limit: limit })
    end

    def send_packet(opcode, packet)
      send({ op: opcode, d: packet }.to_json)
    end

    def send_raw(data, _type = :text)
      send(data)
    end

    private

    def setup_heartbeats(interval)
      @last_heartbeat_acked = true
      @missed_heartbeat_acks = 0
      return if @heartbeat_task

      @heartbeat_interval = interval
      @heartbeat_task = @reactor_task&.async do
        loop do
          if (@session && !@session.suspended?) || !@session
            OnyxCord::AsyncRuntime.sleep(@heartbeat_interval)
            if !@closed && @connection
              @bot.raise_heartbeat_event
              heartbeat
            else
              LOGGER.debug('Tried to heartbeat without connection — skipping.')
            end
          else
            OnyxCord::AsyncRuntime.sleep(1)
          end
        rescue StandardError => e
          LOGGER.error('Error while heartbeating!')
          LOGGER.log_exception(e)
        end
      end
    end

    def connect_loop
      @falloff = 1.0
      @should_reconnect = true

      loop do
        connect
        break unless @should_reconnect

        if @instant_reconnect
          LOGGER.info('Instant reconnection — reconnecting now')
          @instant_reconnect = false
        else
          wait_for_reconnect
        end
      end
    end

    def wait_for_reconnect
      LOGGER.debug("Reconnecting in #{@falloff} seconds.")
      OnyxCord::AsyncRuntime.sleep(@falloff)
      @falloff *= 1.5
      @falloff = 115 + (rand * 10) if @falloff > 120
    end

    def find_gateway
      response = API.gateway(@token)
      JSON.parse(response)['url']
    end

    def process_gateway
      raw_url = @session&.resume_gateway_url || find_gateway
      raw_url += '/' unless raw_url.end_with?('/')

      query = if @compress_mode == :stream
                "?encoding=json&v=#{GATEWAY_VERSION}&compress=zlib-stream"
              else
                "?encoding=json&v=#{GATEWAY_VERSION}"
              end

      raw_url + query
    end

    def connect
      LOGGER.debug('Connecting')

      url = process_gateway
      LOGGER.debug("Gateway URL: #{url}")

      @zlib_reader = Zlib::Inflate.new
      @pipe_broken = false
      @closed = false

      endpoint = websocket_endpoint(url)

      Async::WebSocket::Client.connect(endpoint, extensions: nil) do |connection|
        @connection = connection
        LOGGER.debug('WebSocket connected')

        handle_open

        while (message = connection.read)
          handle_message(message.to_str)
        end
      end
    rescue StandardError => e
      LOGGER.error('Error connecting to gateway!')
      LOGGER.log_exception(e)
    ensure
      @closed = true
      @connection = nil
    end

    def websocket_endpoint(url)
      Async::HTTP::Endpoint.parse(
        url,
        protocol: Async::HTTP::Protocol::HTTP11,
        alpn_protocols: ['http/1.1']
      )
    end

    def handle_open; end

    def handle_error(e)
      LOGGER.error('Error in gateway loop!')
      LOGGER.log_exception(e)
    end

    ZLIB_SUFFIX = "\x00\x00\xFF\xFF".b.freeze
    private_constant :ZLIB_SUFFIX

    def handle_message(msg)
      case @compress_mode
      when :large
        msg = Zlib::Inflate.inflate(msg) if msg.byteslice(0) == 'x'
      when :stream
        @zlib_reader << msg
        return if msg.bytesize < 4 || msg.byteslice(-4, 4) != ZLIB_SUFFIX

        msg = @zlib_reader.inflate('')
      end

      packet = JSON.parse(msg)
      op = packet['op'].to_i

      LOGGER.in(packet)

      @session.sequence = packet['s'] if packet['s'] && @session

      case op
      when Opcodes::DISPATCH
        handle_dispatch(packet)
      when Opcodes::HELLO
        handle_hello(packet)
      when Opcodes::RECONNECT
        handle_reconnect
      when Opcodes::INVALIDATE_SESSION
        handle_invalidate_session(packet)
      when Opcodes::HEARTBEAT_ACK
        handle_heartbeat_ack(packet)
      when Opcodes::HEARTBEAT
        handle_heartbeat(packet)
      else
        LOGGER.warn("Invalid opcode #{op}: #{msg}")
      end
    end

    # Op 0
    def handle_dispatch(packet)
      data = packet['d']
      type = packet['t'].intern

      case type
      when :READY
        LOGGER.info("Discord gateway v#{data['v']}, requested: #{GATEWAY_VERSION}")
        @session = Session.new(data['session_id'], data['resume_gateway_url'])
        @session.sequence = 0
        @bot.__send__(:notify_ready) if @intents && @intents.nobits?(INTENTS[:servers])
      when :RESUMED
        LOGGER.info 'Resumed'
        return
      end

      @bot.dispatch(packet)
    end

    # Op 1
    def handle_heartbeat(packet)
      send_heartbeat(packet['s'])
    end

    # Op 7
    def handle_reconnect
      LOGGER.debug('Received op 7, reconnecting')
      reconnect
    end

    # Op 9
    def handle_invalidate_session(packet)
      LOGGER.debug('Received op 9, invalidating session')
      if @session
        if packet['d'] == true
          reconnect
        else
          @session.invalidate
        end
      else
        LOGGER.warn('Op 9 without session!')
      end
      identify
    end

    # Op 10
    def handle_hello(packet)
      LOGGER.debug('Hello!')
      interval = packet['d']['heartbeat_interval'].to_f / 1000.0
      setup_heartbeats(interval)
      LOGGER.debug("Trace: #{packet['d']['_trace']}")
      LOGGER.debug("Session: #{@session.inspect}")

      if @session&.should_resume?
        @session.resume
        resume
      else
        identify
      end
    end

    # Op 11
    def handle_heartbeat_ack(packet)
      LOGGER.debug("Heartbeat ACK: #{packet.inspect}")
      if @check_heartbeat_acks
        @last_heartbeat_acked = true
        @missed_heartbeat_acks = 0
      end
    end

    def handle_internal_close(e)
      close
      handle_close(e)
    end

    def handle_close(e)
      @bot.__send__(:raise_event, Events::DisconnectEvent.new(@bot))

      if e.respond_to?(:code)
        LOGGER.error("WebSocket close frame! Code: #{e.code}")
        LOGGER.error('Privileged intents not authorized. Enable them in the Discord developer portal.') if e.code == 4014
        @should_reconnect = false if FATAL_CLOSE_CODES.include?(e.code)
      elsif e.is_a?(Exception)
        LOGGER.error('WebSocket closed due to error!')
        LOGGER.log_exception(e)
      else
        LOGGER.error("WebSocket closed: #{e&.inspect || '(no info)'}")
      end
    end

    def send(data, _type = :text, _code = nil)
      LOGGER.out(data)

      raise 'Tried to send to websocket while not connected!' unless @connection && !@closed

      @send_limiter.wait

      @connection.write(data)
      @connection.flush
    rescue StandardError => e
      @pipe_broken = true
      handle_internal_close(e)
    end

    def close(_code = 1000)
      return if @closed

      @session&.suspend
      @closed = true

      begin
        @connection&.close
      rescue StandardError
        # Ignore close errors
      end

      @connection = nil
      handle_close(nil)
    end
  end
end
