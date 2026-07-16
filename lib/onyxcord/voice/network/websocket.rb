# frozen_string_literal: true

module OnyxCord::Voice
  class VoiceWS
    # The version of the voice gateway that's supposed to be used.
    VOICE_GATEWAY_VERSION = 8

    # Default timeout in seconds for each handshake phase
    HANDSHAKE_TIMEOUT = 10

    # Handshake states
    STATE_DISCONNECTED = :disconnected
    STATE_CONNECTING   = :connecting
    STATE_READY        = :ready        # Received Ready (opcode 2)
    STATE_SELECTING    = :selecting    # Sent Select Protocol (opcode 1)
    STATE_ESTABLISHED  = :established  # Received Session Description (opcode 4)
    STATE_RESUMING     = :resuming
    STATE_CLOSED       = :closed

    # Valid state transitions for incoming opcodes
    VALID_TRANSITIONS = {
      STATE_CONNECTING   => { 2 => STATE_READY, 8 => STATE_CONNECTING },
      STATE_READY        => { 4 => STATE_ESTABLISHED },
      STATE_RESUMING     => { 9 => STATE_ESTABLISHED },
      STATE_ESTABLISHED  => {}
    }.freeze

    # @return [VoiceUDP] the UDP voice connection over which the actual audio data is sent.
    # @return [Symbol] the current handshake state
    attr_reader :udp, :state

    # Makes a new voice websocket client, but doesn't connect it (see {#connect} for that)
    # @param channel [Channel] The voice channel to connect to
    # @param bot [Bot] The regular bot to which this vWS is bound
    # @param token [String] The authentication token which is also used for REST requests
    # @param session [String] The voice session ID Discord sends over the regular websocket
    # @param endpoint [String] The endpoint URL to connect to
    def initialize(channel, bot, token, session, endpoint)
      raise 'libsodium is unavailable - unable to create voice bot! Please read https://github.com/kruldevb/OnyxCord/wiki/Installing-libsodium' unless LIBSODIUM_AVAILABLE

      @channel = channel
      @bot = bot
      @token = token
      @session = session

      @endpoint = validate_endpoint(endpoint)
      @server_id = nil
      @bot_user_id = nil
      @resuming = false
      @resume_attempts = 0
      @max_resume_attempts = 3
      @state = STATE_DISCONNECTED

      @udp = VoiceUDP.new
    end

    # Send a connection init packet (op 0)
    # @param server_id [Integer] The ID of the server to connect to
    # @param bot_user_id [Integer] The ID of the bot that is connecting
    # @param session_id [String] The voice session ID
    # @param token [String] The Discord authentication token
    def send_init(server_id, bot_user_id, session_id, token)
      @server_id = server_id
      @bot_user_id = bot_user_id
      send_opcode(
        Opcodes::IDENTIFY,
        {
          server_id: server_id,
          user_id: bot_user_id,
          session_id: session_id,
          token: token
        }
      )
    end

    # Sends the UDP connection packet (op 1)
    # @param ip [String] The IP to bind UDP to
    # @param port [Integer] The port to bind UDP to
    # @param mode [Object] Which mode to use for the voice connection
    def send_udp_connection(ip, port, mode)
      send_opcode(
        Opcodes::SELECT_PROTOCOL,
        {
          protocol: 'udp',
          data: {
            address: ip,
            port: port,
            mode: mode
          }
        }
      )
    end

    # Send a heartbeat (op 3), has to be done every @heartbeat_interval seconds or the connection will terminate
    def send_heartbeat
      @heartbeat_nonce = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      @heartbeat_ack_received = false

      send_opcode(
        Opcodes::HEARTBEAT,
        {
          t: @heartbeat_nonce,
          seq_ack: @seq
        }
      )
    end

    # Send a resume packet (op 7) to reconnect after a dropped connection
    # @param server_id [Integer] The ID of the server
    # @param session_id [String] The voice session ID
    # @param token [String] The voice token
    def send_resume(server_id, session_id, token)
      send_opcode(
        Opcodes::RESUME,
        {
          server_id: server_id,
          session_id: session_id,
          token: token,
          seq_ack: @seq
        }
      )
    end

    # Send a speaking packet (op 5). This determines the green circle around the avatar in the voice channel
    # @param value [true, false, Integer] Whether or not the bot should be speaking, can also be a bitmask denoting audio type.
    # @raise [RuntimeError] if called before the voice session is ready
    def send_speaking(value)
      raise 'Cannot send Speaking before voice session is ready' unless @ready

      # Normalize boolean to bitmask: true → 1 (microphone), false → 0
      speaking = case value
                 when true then 1
                 when false then 0
                 else value.to_i
                 end

      @bot.debug("Speaking: #{speaking}")
      send_opcode(
        Opcodes::SPEAKING,
        {
          speaking: speaking,
          delay: 0,
          ssrc: @ssrc
        }
      )
    end

    # Fields that must never appear in logs
    SENSITIVE_KEYS = %w[token session_id secret_key secret].freeze

    def send_opcode(opcode, data)
      @bot.debug("Sending voice opcode #{opcode} with data: #{sanitize_for_log(data)}")
      @client.send({
        op: opcode,
        d: data
      }.to_json)
    end

    # Event handlers; public for websocket-simple to work correctly
    # @!visibility private
    def websocket_open
      # Give the current thread a name ('Voice Web Socket Internal')
      Thread.current[:onyxcord_name] = 'vws-i'

      @state = STATE_CONNECTING

      # Send the init packet
      send_init(@channel.server.id, @bot.profile.id, @session, @token)
    end

    # Maximum size for incoming WebSocket messages (1 MB)
    MAX_MESSAGE_SIZE = 1_048_576

    # @!visibility private
    def websocket_message(msg)
      if msg.bytesize > MAX_MESSAGE_SIZE
        @bot.logger.warn("Voice WebSocket message too large: #{msg.bytesize} bytes")
        return
      end

      # Try to parse as JSON (text frame)
      begin
        packet = JSON.parse(msg)
      rescue JSON::ParserError
        # Binary frame (DAVE protocol) — not yet implemented
        @bot.debug("Received binary voice WebSocket message (#{msg.bytesize} bytes)")
        return
      end

      @seq = packet['seq'] if packet['seq']

      op = packet['op']

      # Validate state transition
      valid_next = VALID_TRANSITIONS.fetch(@state, {})
      if valid_next.key?(op)
        @state = valid_next[op]
      elsif op == 8 || op == 6 || op == 10 || op == 11
        # Hello, Heartbeat ACK, Client Connect, Client Disconnect are always valid
      else
        @bot.logger.warn("Voice opcode #{op} received in unexpected state #{@state}")
        return
      end

      case op
      when OnyxCord::Voice::Opcodes::READY
        # Opcode 2 contains data to initialize the UDP connection
        @ws_data = packet['d']

        @ssrc = @ws_data['ssrc']
        @port = @ws_data['port']

        @udp_mode = (ENCRYPTION_MODES & @ws_data['modes']).first
        unless @udp_mode
          @bot.logger.error("No compatible encryption mode. Server offers: #{@ws_data['modes']}. Client supports: #{ENCRYPTION_MODES}")
          @client&.close
          @state = STATE_CLOSED
          return
        end

        @udp.connect(@ws_data['ip'], @port, @ssrc)
        @udp.send_discovery
      when OnyxCord::Voice::Opcodes::SESSION_DESCRIPTION
        # Opcode 4 sends the secret key used for encryption
        @ws_data = packet['d']

        # Reset the sequence when starting a new session
        @seq = 0

        @ready = true
        @udp.secret_key = @ws_data['secret_key'].pack('C*')
        @udp.mode = @ws_data['mode']
      when OnyxCord::Voice::Opcodes::HELLO
        # Opcode 8 contains the heartbeat interval.
        @heartbeat_interval = packet['d']['heartbeat_interval']
        send_heartbeat
      when OnyxCord::Voice::Opcodes::HEARTBEAT_ACK
        # Opcode 6 confirms the server received our heartbeat
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        @latency = @heartbeat_nonce ? now - @heartbeat_nonce : nil
        @heartbeat_ack_received = true
        @bot.debug("Voice heartbeat ACK received, latency: #{@latency}ms")
      when OnyxCord::Voice::Opcodes::RESUMED
        # Opcode 9 confirms successful resume
        @ready = true
        @resuming = false
        @bot.debug('Voice connection resumed successfully')
      end
    end

    # Communication goes like this:
    # me                    discord
    #   |                      |
    # websocket connect ->     |
    #   |                      |
    #   |     <- websocket opcode 2
    #   |                      |
    # UDP discovery ->         |
    #   |                      |
    #   |       <- UDP reply packet
    #   |                      |
    # websocket opcode 1 ->    |
    #   |                      |
    # ...
    def connect
      @ws_error = nil

      # Connect websocket
      @thread = Thread.new do
        Thread.current[:onyxcord_name] = 'vws'
        init_ws
      rescue StandardError => e
        @ws_error = e
      end

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + HANDSHAKE_TIMEOUT

      @bot.debug('Started websocket initialization, now waiting for UDP discovery reply')

      # Wait for opcode 2 (sets @ssrc, @port, @udp_mode) via the WS thread
      wait_until('opcode 2 (Ready)', deadline) { @ssrc }

      # Wait for UDP discovery reply with timeout
      ip, port = @udp.receive_discovery_reply(timeout: remaining_time(deadline))
      @bot.debug("UDP discovery reply received! #{ip} #{port}")

      # Send UDP init packet with received UDP data
      @state = STATE_SELECTING
      send_udp_connection(ip, port, @udp_mode)

      @bot.debug('Waiting for op 4 (Session Description) now')

      # Wait for op 4, then finish
      wait_until('opcode 4 (Session Description)', deadline) { @ready }

      raise @ws_error if @ws_error
    end

    # Waits for a condition with a deadline, raising on timeout or WS error.
    def wait_until(phase, deadline, interval = 0.05)
      loop do
        raise @ws_error if @ws_error
        return if yield
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise "Voice handshake timed out waiting for #{phase}" if remaining <= 0
        sleep [interval, remaining].min
      end
    end

    def remaining_time(deadline)
      [deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max
    end

    # Validates the voice endpoint to prevent SSRF and injection attacks
    # Expected format: hostname or hostname:port (e.g., "us-east1.voice.discord.gg:443")
    def validate_endpoint(endpoint)
      raise ArgumentError, 'Voice endpoint is nil or empty' if endpoint.nil? || endpoint.strip.empty?
      raise ArgumentError, "Voice endpoint contains invalid characters: #{endpoint.inspect}" if endpoint.match?(/[^\w.\-:]/)
      raise ArgumentError, 'Voice endpoint must not contain a path' if endpoint.include?('/')
      raise ArgumentError, 'Voice endpoint must not contain userinfo' if endpoint.include?('@')
      endpoint
    end

    # Disconnects the websocket and waits for the thread to finish cooperatively
    def destroy(join_timeout = 5)
      @state = STATE_CLOSED
      @destroying = true
      @heartbeat_running = false
      @client&.close
      @udp.close
      @thread&.join(join_timeout)
      if @thread&.alive?
        @bot.logger.warn('Voice WebSocket thread did not exit cooperatively, interrupting')
        @thread&.raise(Interrupt)
        @thread&.join(2)
      end
    end

    private

    # Returns a copy of data with sensitive values redacted for safe logging.
    def sanitize_for_log(data)
      case data
      when Hash
        data.each_with_object({}) do |(k, v), h|
          h[k] = SENSITIVE_KEYS.include?(k) ? '[REDACTED]' : sanitize_for_log(v)
        end
      when Array
        data.map { |item| sanitize_for_log(item) }
      else
        data
      end
    end

    def heartbeat_loop
      @heartbeat_running = true
      @heartbeat_ack_received = true
      @heartbeat_nonce = nil
      @latency = nil

      while @heartbeat_running
        if @heartbeat_interval
          sleep @heartbeat_interval / 1000.0

          # Zombie connection detection: if we sent a heartbeat but never got an ACK, close
          unless @heartbeat_ack_received
            @bot.logger.warn('Voice heartbeat ACK not received — connection may be zombie')
            @client&.close
            break
          end

          send_heartbeat
        else
          # If no interval has been set yet, sleep a second and check again
          sleep 1
        end
      end
    end

    def init_ws
      host = "wss://#{@endpoint}/?v=#{VOICE_GATEWAY_VERSION}"
      @bot.debug("Connecting VWS to host: #{host}")

      # Connect the WS
      @client = Internal::WebSocket.new(
        host,
        method(:websocket_open),
        method(:websocket_message),
        proc { |e| OnyxCord::LOGGER.error "VWS error: #{e}" },
        method(:handle_ws_close)
      )

      @bot.debug('VWS connected')

      # Block any further execution
      heartbeat_loop
    end

    # Handle WebSocket close events and attempt resume
    def handle_ws_close(close_code)
      @bot.logger.warn("Voice WebSocket closed: #{close_code}")
      @heartbeat_running = false

      return if @destroying

      # Attempt resume if we have a valid session
      if @server_id && @session && @token && @resume_attempts < @max_resume_attempts
        attempt_resume
      else
        @bot.logger.warn("Voice connection lost, resume not possible (attempts: #{@resume_attempts})")
      end
    end

    def attempt_resume
      @resume_attempts += 1
      backoff = [2**@resume_attempts, 30].min
      @bot.debug("Attempting voice resume in #{backoff}s (attempt #{@resume_attempts}/#{@max_resume_attempts})")
      sleep backoff

      @state = STATE_RESUMING
      @resuming = true
      @ready = false
      @heartbeat_ack_received = true

      # Reconnect websocket
      init_ws

      # Send resume after WS open (via websocket_open → send_init path)
      # Actually, we need to send Resume instead of Identify
      @client&.close rescue nil
      @thread&.join(2) rescue nil

      # Reconnect and try resume
      @thread = Thread.new do
        Thread.current[:onyxcord_name] = 'vws-resume'
        init_ws_resume
      end
    end

    def init_ws_resume
      host = "wss://#{@endpoint}/?v=#{VOICE_GATEWAY_VERSION}"
      @client = Internal::WebSocket.new(
        host,
        method(:websocket_open_resume),
        method(:websocket_message),
        proc { |e| OnyxCord::LOGGER.error "VWS resume error: #{e}" },
        method(:handle_ws_close)
      )
      heartbeat_loop
    end

    def websocket_open_resume
      Thread.current[:onyxcord_name] = 'vws-resume-i'
      send_resume(@server_id, @session, @token)
    end
  end
end
