# frozen_string_literal: true

module OnyxCord::Voice
  class VoiceUDP
    # @return [true, false] whether or not UDP communications are encrypted.
    # @deprecated Discord no longer supports unencrypted voice communication.
    attr_accessor :encrypted
    alias_method :encrypted?, :encrypted

    # The UDP encryption mode
    attr_reader :mode

    # @!visibility private
    attr_writer :mode

    # Creates a new UDP connection. Only creates a socket as the discovery reply may come before the data is
    # initialized.
    def initialize
      @socket = UDPSocket.new
      @encrypted = true
      @secret_key = nil
      @send_mutex = Mutex.new
    end

    # Sets the secret key used for encryption
    def secret_key=(key)
      @secret_key = key
    end

    # Redact sensitive fields in inspect output
    def inspect
      "#<#{self.class.name} @ip=#{@ip.inspect} @port=#{@port.inspect} @ssrc=#{@ssrc.inspect} @mode=#{@mode.inspect} @secret_key=[REDACTED]>"
    end

    # Initializes the UDP socket with data obtained from opcode 2.
    # @param ip [String] The IP address to connect to.
    # @param port [Integer] The port to connect to.
    # @param ssrc [Integer] The Super Secret Relay Code (SSRC). Discord uses this to identify different voice users
    #   on the same endpoint.
    def connect(ip, port, ssrc)
      @ip = ip
      @port = port
      @ssrc = ssrc
    end

    # Waits for a UDP discovery reply, and returns the sent data.
    # @param timeout [Numeric] maximum seconds to wait (nil = blocking)
    # @raise [RuntimeError] if the timeout expires or the reply is invalid
    # @return [Array(String, Integer)] the IP and port received from the discovery reply.
    def receive_discovery_reply(timeout: nil)
      if timeout
        ready = IO.select([@socket], nil, nil, timeout)
        raise 'UDP discovery reply timed out' unless ready
      end

      message, _sender = @socket.recvfrom(74)

      # Validate packet structure
      raise 'UDP discovery reply too short' if message.bytesize < 74

      type = message[0..1].unpack1('n')
      raise "UDP discovery reply has unexpected type: 0x#{type.to_s(16)}" unless type == 0x2

      length = message[2..3].unpack1('n')
      raise "UDP discovery reply has unexpected length: #{length}" unless length == 70

      reply_ssrc = message[4..7].unpack1('N')
      raise "UDP discovery reply SSRC mismatch: #{reply_ssrc} != #{@ssrc}" unless reply_ssrc == @ssrc

      # Extract IP (null-terminated within the 64-byte data field starting at offset 8)
      ip = message[8..71].delete("\0")
      port = message[72..73].unpack1('n')

      raise 'UDP discovery reply contains empty IP' if ip.empty?

      [ip, port]
    end

    # Makes an audio packet from a buffer and sends it to Discord.
    # @param buf [String] The audio data to send, must be exactly one Opus frame
    # @param sequence [Integer] The packet sequence number, incremented by one for subsequent packets
    # @param time [Integer] When this packet should be played back, in no particular unit (essentially just the
    #   sequence number multiplied by 960)
    def send_audio(buf, sequence, time)
      @send_mutex.synchronize do
        # Header of the audio packet
        header = generate_header(sequence, time)

        nonce = generate_nonce
        buf = encrypt_audio(buf, header, nonce)
        data = header + buf + nonce.byteslice(0, 4)

        send_packet(data)
      end
    end

    # Sends the UDP discovery packet with the internally stored SSRC. Discord will send a reply afterwards which can
    # be received using {#receive_discovery_reply}
    def send_discovery
      # Create empty packet
      discovery_packet = ''

      # Add Type request (0x1 = request, 0x2 = response)
      discovery_packet += [0x1].pack('n')

      # Add Length (excluding Type and itself = 70)
      discovery_packet += [70].pack('n')

      # Add SSRC
      discovery_packet += [@ssrc].pack('N')

      # Add 66 zeroes so the packet is 74 bytes long
      discovery_packet += "\0" * 66

      send_packet(discovery_packet)
    end

    def close
      @secret_key = nil
      @socket.close unless @socket.closed?
    end

    private

    # Encrypts audio data using libsodium
    # @param buf [String] The encoded audio data to be encrypted
    # @param header [String] The RTP header of the packet, used as associated data
    # @param nonce [String] The nonce to be used to encrypt the data
    # @return [String] the audio data, encrypted
    def encrypt_audio(buf, header, nonce)
      raise 'No secret key found, despite encryption being enabled!' unless @secret_key

      case @mode
      when 'aead_xchacha20_poly1305_rtpsize'
        OnyxCord::Voice::XChaCha20AEAD.encrypt(buf, header, nonce, @secret_key)
      when 'aead_aes256gcm_rtpsize'
        OnyxCord::Voice::AES256GCM.encrypt(buf, header, nonce, @secret_key)
      else
        raise "`#{@mode}' is not a supported encryption mode"
      end
    end

    def send_packet(packet)
      @socket.send(packet, 0, @ip, @port)
    end

    # @return [String]
    def generate_nonce
      case @mode
      when 'aead_xchacha20_poly1305_rtpsize'
        case @incremental_nonce
        when nil, 0xff_ff_ff_ff
          @incremental_nonce = 0
        else
          @incremental_nonce += 1
        end
        [@incremental_nonce].pack('N').ljust(24, "\0")
      when 'aead_aes256gcm_rtpsize'
        case @incremental_nonce
        when nil, 0xff_ff_ff_ff
          @incremental_nonce = 0
        else
          @incremental_nonce += 1
        end
        # AES-256-GCM uses 12-byte nonce: 4 bytes counter + 8 bytes zero padding
        [@incremental_nonce].pack('N').ljust(12, "\0")
      else
        raise "`#{@mode}' is not a supported encryption mode"
      end
    end

    # @return [String]
    def generate_header(sequence, time)
      raise ArgumentError, "Invalid sequence: #{sequence}" unless sequence.is_a?(Integer) && sequence.between?(0, 0xFFFF)
      raise ArgumentError, "Invalid timestamp: #{time}" unless time.is_a?(Integer) && time.between?(0, 0xFFFFFFFF)
      raise ArgumentError, "Invalid SSRC: #{@ssrc}" unless @ssrc.is_a?(Integer) && @ssrc.between?(0, 0xFFFFFFFF)

      [0x80, 0x78, sequence, time, @ssrc].pack('CCnNN')
    end
  end

  # Represents a websocket client connection to the voice server. The websocket connection (sometimes called vWS) is
  # used to manage general data about the connection, such as sending the speaking packet, which determines the green
  # circle around users on Discord, and obtaining UDP connection info.
end
