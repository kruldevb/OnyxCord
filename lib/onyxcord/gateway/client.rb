# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'async/http/protocol/http11'
require 'async/websocket/client'
require_relative '../internal/async_runtime'
require_relative '../internal/rate_limiter/gateway'
require_relative '../internal/gateway/opcodes'
require_relative '../internal/gateway/close_codes'
require 'protocol/websocket'

module OnyxCord
  module Gateway
    class Client
      LARGE_THRESHOLD = 100
      GATEWAY_VERSION = ENV.fetch('DISCORD_GATEWAY_VERSION', '10').to_i

      STOP = Object.new.freeze
      private_constant :STOP

      attr_accessor :check_heartbeat_acks
      attr_reader :intents, :latency, :state, :generation

      def initialize(bot, token, shard_key = nil, compress_mode = :stream, intents = ALL_INTENTS)
        @token = token
        @bot = bot
        @shard_key = shard_key
        @compress_mode = compress_mode
        @intents = intents
        @check_heartbeat_acks = true

        @state = :idle
        @generation = 0
        @mutex = Mutex.new

        @sequence = nil
        @session = nil
        @connection = nil
        @latency = nil

        @heartbeat_interval = nil
        @heartbeat_task = nil
        @last_heartbeat_acked = true
        @pending_heartbeat_sent_at = nil

        @send_limiter = Internal::RateLimiter::Gateway.new
        @write_queue = Queue.new
        @write_thread = nil

        @backoff = 1.0
        @stop_requested = false
        @reconnect_requested = false
        @resume_on_reconnect = false

        @zlib_reader = nil
      end

      def run_async
        @task = Internal::AsyncRuntime.async { run }
        @bot.logger.debug('Gateway task created')
      end

      def run
        connect_loop
      end

      def sync
        @task&.wait
      end

      def open?
        @state == :ready
      end

      def stop_requested?
        @stop_requested
      end

      def stop
        @stop_requested = true
        close_connection(1000, 'Client stopped')
        transition_to(:stopped) unless @state == :stopped
        nil
      end

      def kill
        @stop_requested = true
        stop_writer
        @task&.stop
      end

      def notify_ready
        @bot.logger.debug('Gateway ready')
      end

      def inject_reconnect(url = nil)
        @reconnect_requested = true
        @resume_on_reconnect = false
        close_connection(4000, 'Reconnect requested')
      end

      def inject_resume(seq)
        @reconnect_requested = true
        @resume_on_reconnect = true
        close_connection(4000, 'Resume requested')
      end

      def inject_error(e)
        handle_error(e)
      end

      # Heartbeat — called by the heartbeat task
      def heartbeat
        if @check_heartbeat_acks
          unless @last_heartbeat_acked
            @bot.logger.warn('Heartbeat not acked — zombie connection')
            close_connection(1000, 'Zombie connection')
            return
          end
          @last_heartbeat_acked = false
        end

        send_heartbeat(@sequence)
      end

      def send_heartbeat(sequence)
        @pending_heartbeat_sent_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        enqueue_write(Internal::Gateway::Opcodes::HEARTBEAT, sequence || 0, priority: true)
      end

      def identify
        compress = @compress_mode == :large
        data = {
          token: @token,
          properties: {
            os: RUBY_PLATFORM,
            browser: 'onyxcord',
            device: 'onyxcord'
          },
          compress: compress,
          large_threshold: LARGE_THRESHOLD,
          intents: @intents
        }
        data[:shard] = @shard_key if @shard_key
        enqueue_write(Internal::Gateway::Opcodes::IDENTIFY, data)
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
        enqueue_write(Internal::Gateway::Opcodes::IDENTIFY, data)
      end

      def send_status_update(status, since, activity, afk)
        enqueue_write(Internal::Gateway::Opcodes::PRESENCE, {
          status: status,
          since: since,
          activities: activity ? [activity] : [],
          afk: afk
        })
      end

      def send_voice_state_update(server_id, channel_id, self_mute, self_deaf)
        enqueue_write(Internal::Gateway::Opcodes::VOICE_STATE, {
          guild_id: server_id, channel_id: channel_id,
          self_mute: self_mute, self_deaf: self_deaf
        })
      end

      def resume
        send_resume(@token, @session.session_id, @sequence)
      end

      def send_resume(token, session_id, seq)
        enqueue_write(Internal::Gateway::Opcodes::RESUME, { token: token, session_id: session_id, seq: seq })
      end

      def send_request_members(server_id, query, limit, nonce = nil)
        payload = { guild_id: server_id, query: query, limit: limit }
        payload[:nonce] = nonce if nonce
        enqueue_write(Internal::Gateway::Opcodes::REQUEST_MEMBERS, payload)
      end

      def send_packet(opcode, packet)
        enqueue_write(opcode, packet)
      end

      def send_raw(data, _type = :text)
        raw_enqueue(data)
      end

      def reconnect(resume: true)
        @session&.invalidate unless resume
        @reconnect_requested = true
        @resume_on_reconnect = resume
        close_connection(4000, 'Reconnect')
      end

      private

      # --- State machine ---

      def transition_to(new_state)
        old = @state
        @state = new_state
        @bot.logger.debug("Gateway state: #{old} → #{new_state}")
      end

      # --- Write queue ---

      def start_writer
        @write_thread = Thread.new { writer_loop }
        @write_thread.abort_on_exception = false
      end

      def stop_writer
        @write_queue.push(STOP) if @write_thread&.alive?
        @write_thread&.join(2)
        @write_thread = nil
      end

      def writer_loop
        loop do
          item = @write_queue.pop
          break if item.equal?(STOP)

          begin
            data = item[:data]
            @send_limiter.wait unless item[:priority]
            @connection&.write(data)
            @connection&.flush
          rescue StandardError => e
            @bot.logger.error("Write failed: #{e.message}")
          end
        end
      end

      def enqueue_write(opcode, packet, priority: false)
        data = { op: opcode, d: packet }.to_json
        @write_queue.push({ data: data, priority: priority })
      end

      def raw_enqueue(data)
        @write_queue.push({ data: data, priority: false })
      end

      # --- Heartbeat ---

      def setup_heartbeats(interval)
        @heartbeat_interval = interval
        @last_heartbeat_acked = true

        @heartbeat_task&.stop
        @heartbeat_task = Async::Task.current&.async do
          # First heartbeat with jitter
          jitter = rand * interval
          Internal::AsyncRuntime.sleep(jitter)
          heartbeat unless @state == :stopped

          loop do
            Internal::AsyncRuntime.sleep(interval)
            break if @state == :stopped
            heartbeat
          rescue StandardError => e
            @bot.logger.error("Heartbeat error: #{e.message}")
          end
        end
      end

      def cancel_heartbeat
        @heartbeat_task&.stop
        @heartbeat_task = nil
      end

      # --- Connection ---

      def connect_loop
        @backoff = 1.0
        @stop_requested = false

        loop do
          break if @stop_requested

          connect
          break if @stop_requested

          if @reconnect_requested
            @reconnect_requested = false
            @bot.logger.debug('Reconnecting immediately')
          else
            wait_for_reconnect
          end
        end

        transition_to(:stopped) unless @state == :stopped
        @bot.logger.debug('Gateway loop exited')
      end

      def wait_for_reconnect
        @bot.logger.debug("Reconnecting in #{@backoff.round(1)}s")
        Internal::AsyncRuntime.sleep(@backoff)
        @backoff = [@backoff * 1.5, 125.0].min + rand * 5
      end

      def reset_backoff
        @backoff = 1.0
      end

      def find_gateway
        response = REST.gateway(@token)
        JSON.parse(response)['url']
      end

      def process_gateway
        raw_url = (@resume_on_reconnect && @session&.resume_gateway_url) || find_gateway
        raw_url += '/' unless raw_url.end_with?('/')

        query = if @compress_mode == :stream
                  "?encoding=json&v=#{GATEWAY_VERSION}&compress=zlib-stream"
                else
                  "?encoding=json&v=#{GATEWAY_VERSION}"
                end

        raw_url + query
      end

      def connect
        gen = @generation
        transition_to(:connecting)

        url = process_gateway
        @bot.logger.debug("Connecting to #{url}")

        @zlib_reader = Zlib::Inflate.new if @compress_mode == :stream
        @sequence = nil
        @send_limiter.reset

        endpoint = websocket_endpoint(url)

        start_writer

        Async::WebSocket::Client.connect(endpoint, extensions: nil) do |connection|
          break unless gen == @generation

          @connection = connection
          transition_to(:awaiting_hello)

          while (message = connection.read)
            break unless gen == @generation
            handle_message(message.to_str, gen)
          end
        end
      rescue Protocol::WebSocket::ClosedError => e
        handle_remote_close(e, gen)
      rescue EOFError => e
        handle_remote_close(e, gen)
      rescue StandardError => e
        @bot.logger.error("Connection error: #{e.class}: #{e.message}")
        @bot.logger.log_exception(e) if e.respond_to?(:backtrace)
      ensure
        @connection = nil
        stop_writer
        @zlib_reader = nil if @zlib_reader

        if gen == @generation && !@stop_requested
          transition_to(:closing)
        end
      end

      def websocket_endpoint(url)
        Async::HTTP::Endpoint.parse(
          url,
          protocol: Async::HTTP::Protocol::HTTP11,
          alpn_protocols: ['http/1.1']
        )
      end

      # --- Message handling ---

      ZLIB_SUFFIX = "\x00\x00\xFF\xFF".b.freeze
      private_constant :ZLIB_SUFFIX

      def handle_message(msg, gen)
        msg = decompress(msg)
        return unless msg

        packet = JSON.parse(msg)
        op = packet['op'].to_i

        @bot.logger.in(packet)

        # Update sequence on every packet with a sequence number
        @sequence = packet['s'] if packet['s']

        case op
        when Internal::Gateway::Opcodes::DISPATCH
          handle_dispatch(packet, gen)
        when Internal::Gateway::Opcodes::HELLO
          handle_hello(packet, gen)
        when Internal::Gateway::Opcodes::RECONNECT
          handle_reconnect(gen)
        when Internal::Gateway::Opcodes::INVALIDATE_SESSION
          handle_invalidate_session(packet, gen)
        when Internal::Gateway::Opcodes::HEARTBEAT_ACK
          handle_heartbeat_ack
        when Internal::Gateway::Opcodes::HEARTBEAT
          handle_heartbeat_request(packet)
        else
          @bot.logger.warn("Unknown opcode #{op}")
        end
      end

      def decompress(msg)
        case @compress_mode
        when :large
          msg.byteslice(0) == 'x' ? Zlib::Inflate.inflate(msg) : msg
        when :stream
          @zlib_reader << msg
          return nil if msg.bytesize < 4 || msg.byteslice(-4, 4) != ZLIB_SUFFIX
          @zlib_reader.inflate('')
        else
          msg
        end
      end

      # --- Opcode handlers ---

      def handle_dispatch(packet, gen)
        return unless gen == @generation

        data = packet['d']
        type = packet['t']&.intern

        case type
        when :READY
          handle_ready(data)
        when :RESUMED
          handle_resumed
        end

        @bot.dispatch(packet)
      end

      def handle_ready(data)
        @bot.logger.info("Ready! Gateway v#{data['v']}, session #{data['session_id']}")
        @session = Internal::Gateway::Session.new(data['session_id'], data['resume_gateway_url'])
        reset_backoff
        transition_to(:ready)
        @bot.__send__(:notify_ready) if @intents && @intents.nobits?(INTENTS[:servers])
      end

      def handle_resumed
        @bot.logger.info('Resumed session')
        reset_backoff
        transition_to(:ready)
        @bot.__send__(:notify_ready) if @intents && @intents.nobits?(INTENTS[:servers])
      end

      def handle_hello(packet, gen)
        return unless gen == @generation

        transition_to(:awaiting_hello) unless @state == :awaiting_hello
        interval = packet['d']['heartbeat_interval'].to_f / 1000.0
        setup_heartbeats(interval)

        if @session&.should_resume?
          transition_to(:resuming)
          @session.resume
          resume
        else
          transition_to(:identifying)
          identify
        end
      end

      def handle_heartbeat_request(packet)
        send_heartbeat(packet['s'] || @sequence)
      end

      def handle_reconnect(gen)
        return unless gen == @generation

        @bot.logger.debug('Received op 7 reconnect')
        @session&.suspend
        @reconnect_requested = true
        @resume_on_reconnect = true
        close_connection(4000, 'Server requested reconnect')
      end

      def handle_invalidate_session(packet, gen)
        return unless gen == @generation

        d = packet['d']
        if d == true
          @bot.logger.debug('Op 9 (resumable) — suspending session')
          @session&.suspend
          @reconnect_requested = true
          @resume_on_reconnect = true
          close_connection(4000, 'Invalid session (resumable)')
        else
          @bot.logger.debug('Op 9 (not resumable) — invalidating session')
          @session&.invalidate
          @reconnect_requested = true
          @resume_on_reconnect = false
          close_connection(4000, 'Invalid session')
        end
      end

      def handle_heartbeat_ack(_packet = nil)
        if @pending_heartbeat_sent_at
          @latency = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @pending_heartbeat_sent_at
        end
        @last_heartbeat_acked = true
      end

      def handle_remote_close(e, gen)
        return unless gen == @generation

        code = e.respond_to?(:code) ? e.code : nil
        info = code ? Internal::Gateway.close_info(code) : nil

        @bot.logger.warn("Remote close: #{e.class} code=#{code}")

        # Suspend session for recoverable drops
        if info
          @session&.invalidate if info.invalidate?
          @session&.suspend if info.reconnect? && !info.invalidate?
        else
          # Unknown close — assume recoverable, suspend for resume
          @session&.suspend
        end

        # Raise disconnect event
        begin
          @bot.__send__(:raise_event, Events::DisconnectEvent.new(@bot))
        rescue StandardError
          nil
        end

        if info&.fatal?
          @stop_requested = true
          transition_to(:stopped)
        else
          @reconnect_requested = true
          @resume_on_reconnect = info ? info.resume? : true
          transition_to(:closing)
        end
      end

      # --- Close ---

      def close_connection(code = 1000, reason = '')
        return if @state == :stopped || @state == :closing

        transition_to(:closing)
        cancel_heartbeat

        begin
          @connection&.close(code, reason)
        rescue StandardError
          nil
        end

        @connection = nil
        stop_writer
      end

      def handle_error(e)
        @bot.logger.error('Gateway error!')
        @bot.logger.log_exception(e)
      end
    end
  end
end
