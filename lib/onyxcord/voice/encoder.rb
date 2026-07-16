# frozen_string_literal: true

# This makes opus an optional dependency
begin
  require 'opus-ruby'
  OPUS_AVAILABLE = true
rescue LoadError
  OPUS_AVAILABLE = false
end

require 'open3'

# Discord voice chat support
module OnyxCord::Voice
  # This class conveniently abstracts opus and ffmpeg/avconv, for easy implementation of voice sending. It's not very
  # useful for most users, but I guess it can be useful sometimes.
  class Encoder
    # Whether or not avconv should be used instead of ffmpeg. If possible, it is recommended to use ffmpeg instead,
    # as it is better supported.
    # @return [true, false] whether avconv should be used instead of ffmpeg.
    attr_accessor :use_avconv

    # @see Client#filter_volume=
    # @return [Integer] the volume used as a filter to ffmpeg/avconv.
    attr_accessor :filter_volume

    # Audio constants for Discord voice (48kHz stereo, 20ms frames)
    SAMPLE_RATE = 48_000
    CHANNELS = 2
    FRAME_SIZE = 960          # samples per channel (20ms at 48kHz)
    BYTES_PER_SAMPLE = 2      # s16le
    FRAME_BYTES = FRAME_SIZE * CHANNELS * BYTES_PER_SAMPLE  # 3840

    # Create a new encoder
    def initialize
      @filter_volume = 1

      raise LoadError, 'Opus unavailable - voice not supported! Please install opus for voice support to work.' unless OPUS_AVAILABLE

      @opus = Opus::Encoder.new(SAMPLE_RATE, FRAME_SIZE, CHANNELS)
    end

    # Set the opus encoding bitrate
    # @param value [Integer] The new bitrate to use, in bits per second (so 64000 if you want 64 kbps)
    # @raise [ArgumentError] if value is not a valid bitrate
    def bitrate=(value)
      raise ArgumentError, 'Bitrate must be a numeric value' unless value.is_a?(Numeric)
      raise ArgumentError, 'Bitrate must be positive' if value <= 0
      raise ArgumentError, 'Bitrate cannot be NaN or Infinity' if value.nan? || value.infinite?
      raise ArgumentError, 'Bitrate out of Opus range (500-512000 bps)' unless value.between?(500, 512_000)

      @opus.bitrate = value.to_i
    end

    # Encodes the given buffer using opus.
    # @param buffer [String] An unencoded PCM (s16le) buffer, must be FRAME_BYTES (3840) bytes.
    # @return [String] A buffer encoded using opus.
    def encode(buffer)
      raise ArgumentError, "PCM buffer must be #{FRAME_BYTES} bytes, got #{buffer.bytesize}" unless buffer.bytesize == FRAME_BYTES

      @opus.encode(buffer, FRAME_SIZE * CHANNELS)
    end

    # One frame of complete silence Opus encoded
    OPUS_SILENCE = [0xF8, 0xFF, 0xFE].pack('C*').freeze

    # Adjusts the volume of a given buffer of s16le PCM data.
    # Processes in-place using binary string operations to avoid Array allocation.
    # @param buf [String] An unencoded PCM (s16le) buffer.
    # @param mult [Float] The volume multiplier, 1 for same volume.
    # @return [String] The buffer with adjusted volume, s16le again
    def adjust_volume(buf, mult)
      return unless buf

      result = String.new(encoding: Encoding::BINARY, capacity: buf.bytesize)
      offset = 0

      while offset + 1 < buf.bytesize
        sample = buf.getbyte(offset) | (buf.getbyte(offset + 1) << 8)
        sample = sample - 0x10000 if sample >= 0x8000  # Convert to signed

        sample = (sample * mult).to_i
        sample = 32_767 if sample > 32_767
        sample = -32_768 if sample < -32_768

        sample &= 0xFFFF  # Convert back to unsigned 16-bit
        result << (sample & 0xFF).chr
        result << ((sample >> 8) & 0xFF).chr
        offset += 2
      end

      result
    end

    # Maximum bytes to capture from ffmpeg stderr
    STDERR_LIMIT = 8192

    # Allowed URL protocols for FFmpeg input
    ALLOWED_PROTOCOLS = %w[http https].freeze

    # Blocked URL protocols that could access local resources or dangerous systems
    BLOCKED_PROTOCOLS = %w[file pipe data srt udp tcp gopher rtsp rtmp].freeze

    # Encodes a given file (or rather, decodes it) using ffmpeg. This accepts pretty much any format, even videos with
    # an audio track. For a list of supported formats, see https://ffmpeg.org/general.html#Audio-Codecs.
    # @param file [String] The path or URL to encode.
    # @param options [Array<String>, String] ffmpeg options to pass after the -i flag. Array preferred.
    # @raise [ArgumentError] if the input protocol is not allowed
    # @return [IO] the audio, encoded as s16le PCM
    def encode_file(file, options = nil)
      validate_input_protocol(file)
      command = ffmpeg_command(input: file, options: options)
      stdout, stderr, wait_thr = Open3.popen2e(*command)
      @last_ffmpeg_stderr = nil
      @last_ffmpeg_wait_thr = wait_thr

      # Capture stderr in a background thread with size limit
      Thread.new do
        Thread.current[:onyxcord_name] = 'ffmpeg-stderr'
        @last_ffmpeg_stderr = stderr.read(STDERR_LIMIT)
        stderr.close
      end

      stdout
    end

    # Encodes an arbitrary IO audio stream using ffmpeg. Accepts pretty much any media format, even videos with audio
    # tracks. For a list of supported audio formats, see https://ffmpeg.org/general.html#Audio-Codecs.
    # @param io [IO] The stream to encode.
    # @param options [Array<String>, String] ffmpeg options to pass after the -i flag. Array preferred.
    # @return [IO] the audio, encoded as s16le PCM
    def encode_io(io, options = nil)
      command = ffmpeg_command(options: options)
      stdout, stderr, wait_thr = Open3.popen2e(*command, in: io)
      @last_ffmpeg_stderr = nil
      @last_ffmpeg_wait_thr = wait_thr

      Thread.new do
        Thread.current[:onyxcord_name] = 'ffmpeg-stderr'
        @last_ffmpeg_stderr = stderr.read(STDERR_LIMIT)
        stderr.close
      end

      stdout
    end

    # Returns the last ffmpeg stderr output (limited to {STDERR_LIMIT} bytes)
    # @return [String, nil]
    def last_ffmpeg_error
      @last_ffmpeg_stderr
    end

    # Returns the exit status of the last ffmpeg process, waiting if necessary
    # @return [Process::Status, nil]
    def last_ffmpeg_status
      @last_ffmpeg_wait_thr&.value
    end

    private

    # Validates that the input protocol is safe (not a dangerous URL scheme)
    def validate_input_protocol(input)
      return unless input.is_a?(String)

      # Check if it looks like a URL (has a scheme)
      if input.match?(%r{\A[a-zA-Z][a-zA-Z0-9+\-.]*://})
        scheme = input.split('://').first.downcase
        raise ArgumentError, "Protocol '#{scheme}' is not allowed for FFmpeg input" if BLOCKED_PROTOCOLS.include?(scheme)
        raise ArgumentError, "Protocol '#{scheme}' is not in the allowed list (#{ALLOWED_PROTOCOLS.join(', ')})" unless ALLOWED_PROTOCOLS.include?(scheme)
      end
    end

    def ffmpeg_command(input: '-', options: nil)
      args = [
        @use_avconv ? 'avconv' : 'ffmpeg',
        '-loglevel', '0',
        '-i', input
      ]

      # Input options (before filters and output)
      args.concat(options.is_a?(Array) ? options : options.to_s.split) if options

      # Audio filters and output format
      args.concat(filter_volume_args)
      args.concat(['-f', 's16le', '-ar', '48000', '-ac', '2', 'pipe:1'])

      args.reject! { |segment| segment.nil? || segment == '' }
      args
    end

    def filter_volume_args
      return [] if @filter_volume == 1

      if @use_avconv
        ['-vol', (@filter_volume * 256).ceil.to_s]
      else
        ['-af', "volume=#{@filter_volume}"]
      end
    end
  end
end
