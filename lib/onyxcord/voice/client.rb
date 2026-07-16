# frozen_string_literal: true

require 'onyxcord/voice/encoder'
require 'onyxcord/voice/network'
require 'onyxcord/voice/timer'
require 'onyxcord/core/logger'
require 'ffi'

# Voice support
module OnyxCord::Voice
  # How long one voice packet should ideally be (20ms as defined by Discord)
  IDEAL_LENGTH = 20.0

  # How many bytes of data to read from audio PCM data (960 samples * 2 channels * 2 bytes)
  DATA_LENGTH = Encoder::FRAME_BYTES

  # This class represents a connection to a Discord voice server and channel. It can be used to play audio files and
  # streams and to control playback on currently playing tracks. The method {Bot#voice_connect} can be used to connect
  # to a voice channel.
  #
  # onyxcord does latency adjustments every now and then to improve playback quality. I made sure to put useful
  # defaults for the adjustment parameters, but if the sound is patchy or too fast (or the speed varies a lot) you
  # should check the parameters and adjust them to your connection: {Client#adjust_interval},
  # {Client#adjust_offset}, and {Client#adjust_average}.
  class Client
    # @return [Channel] the current voice channel
    attr_reader :channel

    # @!visibility private
    attr_writer :channel

    # @return [Integer, nil] the amount of time the stream has been playing, or `nil` if nothing has been played yet.
    attr_reader :stream_time

    # @return [Encoder] the encoder used to encode audio files into the format required by Discord.
    attr_reader :encoder

    # The factor the audio's volume should be multiplied with. `1` is no change in volume, `0` is completely silent,
    # `0.5` is half the default volume and `2` is twice the default.
    # @return [Float] the volume for audio playback, `1.0` by default.
    # @raise [ArgumentError] if value is not a valid volume multiplier
    def volume=(value)
      raise ArgumentError, 'Volume must be a numeric value' unless value.is_a?(Numeric)
      raise ArgumentError, 'Volume cannot be NaN or Infinity' if value.nan? || value.infinite?
      raise ArgumentError, 'Volume must be non-negative' if value.negative?

      @volume = value
    end

    attr_reader :volume

    # @!visibility private
    def initialize(channel, bot, token, session, endpoint)
      @bot = bot
      @channel = channel

      @sequence = @time = 0
      @skips = 0
      @adjust_debug = false

      @volume = 1.0
      @playing = false
      @stop_queue = Thread::Queue.new
      @playback_mutex = Mutex.new

      # Create encoder first (no IO, can fail cheaply)
      @encoder = Encoder.new

      # Create WebSocket (opens UDP socket)
      @ws = VoiceWS.new(channel, bot, token, session, endpoint)
      @udp = @ws.udp

      @ws.connect
    rescue StandardError => e
      @ws&.destroy
      @bot.logger.log_exception(e)
      raise
    end

    # @return [true, false] whether audio data sent will be encrypted.
    # @deprecated Discord no longer supports unencrypted voice communication.
    def encrypted?
      true
    end

    # Set the filter volume. This volume is applied as a filter for decoded audio data. It has the advantage that using
    # it is much faster than regular volume, but it can only be changed before starting to play something.
    # @param value [Integer] The value to set the volume to. For possible values, see {#volume}
    def filter_volume=(value)
      @encoder.filter_volume = value
    end

    # @see #filter_volume=
    # @return [Integer] the volume used as a filter for ffmpeg/avconv.
    def filter_volume
      @encoder.filter_volume
    end

    # Pause playback. This is not instant; it may take up to 20 ms for this change to take effect. (This is usually
    # negligible.)
    def pause
      @paused = true
    end

    # @see #play
    # @return [true, false] Whether it is playing sound or not.
    def playing?
      @playing
    end

    alias_method :isplaying?, :playing?

    # Continue playback. This change may take up to 100ms to take effect, which is usually negligible.
    def continue
      @paused = false
    end

    # Maximum number of frames to skip (5 minutes worth)
    MAX_SKIP_FRAMES = 15_000

    # Skips to a later time in the song. It's impossible to go back without replaying the song.
    # @param secs [Float] How many seconds to skip forwards. Skipping will always be done in discrete intervals of
    #   0.05 seconds, so if the given amount is smaller than that, it will be rounded up.
    # @raise [ArgumentError] if secs is negative, NaN, Infinity, or would exceed max skip
    def skip(secs)
      raise ArgumentError, 'Skip value must be numeric' unless secs.is_a?(Numeric)
      raise ArgumentError, 'Skip value cannot be NaN or Infinity' if secs.nan? || secs.infinite?
      raise ArgumentError, 'Skip value must be non-negative' if secs.negative?

      frames = (secs * (1000 / IDEAL_LENGTH)).ceil
      raise ArgumentError, "Skip exceeds maximum (#{MAX_SKIP_FRAMES} frames)" if @skips + frames > MAX_SKIP_FRAMES

      @skips += frames
    end

    # Sets whether or not the bot is speaking (green circle around user).
    # @param value [true, false, Integer] whether or not the bot should be speaking, or a bitmask denoting the audio type
    # @note https://discord.com/developers/docs/topics/voice-connections#speaking for information on the speaking bitmask
    def speaking=(value)
      @speaking = value
      @ws.send_speaking(value)
    end

    # Stops the current playback entirely.
    # @param wait_for_confirmation [true, false] Whether the method should wait for confirmation from the playback
    #   method that the playback has actually stopped.
    # @param timeout [Numeric] Maximum seconds to wait for confirmation (default 10)
    def stop_playing(wait_for_confirmation = false, timeout: 10)
      @was_playing_before = @playing
      @playing = false

      if @was_playing_before
        # Let play_internal handle its own cleanup (silence frames + Speaking 0)
        sleep IDEAL_LENGTH / 1000.0
      elsif @speaking
        # External stop: send silence frames + Speaking 0 ourselves
        send_silence_frames
      end

      return unless wait_for_confirmation

      # Drain any stale signals, then block for the real one
      @stop_queue.clear
      result = @stop_queue.pop(timeout: timeout)
      raise 'Voice playback stop timed out' if result.nil?
    end

    # Permanently disconnects from the voice channel; to reconnect you will have to call {Bot#voice_connect} again.
    def destroy
      stop_playing
      @bot.voice_destroy(@channel.server.id, false)
      @ws.destroy
    end

    # Plays a stream of raw data to the channel. All playback methods are blocking, i.e. they wait for the playback to
    # finish before exiting the method. This doesn't cause a problem if you just use onyxcord events/commands to
    # play stuff, as these are fully threaded, but if you don't want this behaviour anyway, be sure to call these
    # methods in separate threads.
    # @param encoded_io [IO] A stream of raw PCM data (s16le)
    def play(encoded_io)
      @playback_mutex.synchronize do
        stop_playing(true) if @playing
        @first_packet = true
        pcm_buffer = ''.b

        play_internal do
        # Accumulate partial reads until we have a full frame
        while pcm_buffer.bytesize < DATA_LENGTH
          begin
            chunk = encoded_io.readpartial(DATA_LENGTH - pcm_buffer.bytesize)
            pcm_buffer << chunk
          rescue EOFError, IOError => e
            if @first_packet && pcm_buffer.empty?
              raise IOError, 'File or stream not found!'
            end

            @bot.debug("EOF reached with #{pcm_buffer.bytesize} bytes remaining")
            # Pad incomplete final frame with silence
            pcm_buffer << "\0".b * (DATA_LENGTH - pcm_buffer.bytesize) unless pcm_buffer.empty?
            break
          end
        end

        if pcm_buffer.empty?
          @bot.debug('No more data to read')
          next :stop
        end

        buf = pcm_buffer.byteslice(0, DATA_LENGTH)
        pcm_buffer = pcm_buffer.byteslice(DATA_LENGTH..)

        @first_packet = false

        # Adjust volume
        buf = @encoder.adjust_volume(buf, @volume) if @volume != 1.0 # rubocop:disable Lint/FloatComparison

        # Encode data
        @encoder.encode(buf)
      end
      end
    ensure
      kill_ffmpeg(encoded_io) if encoded_io&.pid
      encoded_io&.close unless encoded_io&.closed?
    end

    # Plays an encoded audio file of arbitrary format to the channel.
    # @see Encoder#encode_file
    # @see #play
    def play_file(file, options = '')
      play @encoder.encode_file(file, options)
    end

    # Plays a stream of encoded audio data of arbitrary format to the channel.
    # @see Encoder#encode_io
    # @see #play
    def play_io(io, options = '')
      play @encoder.encode_io(io, options)
    end

    # Plays a stream of audio data in the DCA format. This format has the advantage that no recoding has to be
    # done - the file contains the data exactly as Discord needs it.
    # @note DCA playback will not be affected by the volume modifier ({#volume}) because the modifier operates on raw
    #   PCM, not opus data. Modifying the volume of DCA data would involve decoding it, multiplying the samples and
    #   re-encoding it, which defeats its entire purpose (no recoding).
    # @see https://github.com/bwmarrin/dca
    # @see #play
    # Maximum allowed DCA metadata size (1 MB)
    MAX_DCA_METADATA_SIZE = 1_048_576
    # Maximum allowed DCA frame size (1 MB)
    MAX_DCA_FRAME_SIZE = 1_048_576

    def play_dca(file)
      @playback_mutex.synchronize do
        stop_playing(true) if @playing

        @bot.debug "Reading DCA file #{file}"

        File.open(file, 'rb') do |input_stream|
        magic = input_stream.read(4)
        raise ArgumentError, 'Not a DCA1 file! The file might have been corrupted, please recreate it.' unless magic == 'DCA1'

        # Read the metadata header, then read the metadata and discard it
        metadata_header_bytes = input_stream.read(4)
        raise ArgumentError, 'DCA file truncated at metadata header' unless metadata_header_bytes&.bytesize == 4

        metadata_size = metadata_header_bytes.unpack1('l<')
        raise ArgumentError, "DCA metadata too large: #{metadata_size} bytes" if metadata_size.negative? || metadata_size > MAX_DCA_METADATA_SIZE

        metadata = input_stream.read(metadata_size)
        raise ArgumentError, 'DCA file truncated at metadata' unless metadata&.bytesize == metadata_size

        # Play the data, without re-encoding it to opus
        play_internal do
          begin
            # Read frame header (2 bytes, little-endian signed int = frame size)
            header_str = input_stream.read(2)

            unless header_str
              @bot.debug 'Finished DCA parsing (header is nil)'
              next :stop
            end

            raise ArgumentError, 'DCA file truncated at frame header' unless header_str.bytesize == 2

            header = header_str.unpack1('s<')

            raise ArgumentError, 'Negative header in DCA file! Your file is likely corrupted.' if header.negative?
            raise ArgumentError, "DCA frame too large: #{header} bytes" if header > MAX_DCA_FRAME_SIZE
          rescue EOFError
            @bot.debug 'Finished DCA parsing (EOFError)'
            next :stop
          end

          # Read the frame data
          frame = input_stream.read(header)
          unless frame&.bytesize == header
            @bot.debug "DCA frame truncated: expected #{header} bytes, got #{frame&.bytesize || 0}"
            next :stop
          end

          frame
        end
      end
      end
    end

    alias_method :play_stream, :play_io

    private

    # Plays the data from the IO stream as Discord requires it
    def play_internal
      count = 0
      @playing = true
      self.speaking = true

      last_sent = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

      loop do
        # If paused, wait
        sleep 0.1 while @paused

        break unless @playing

        # Get timestamp before encoding
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

        # If we should skip, get some data, discard it and go to the next iteration
        if @skips.positive?
          @skips -= 1
          yield
          next
        end

        # Track packet count, sequence and time (Discord requires this)
        count += 1
        increment_packet_headers

        # Get packet data
        buf = yield

        # Stop doing anything if the stop signal was sent
        break if buf == :stop

        # Proceed to the next packet if we got nil
        next unless buf

        # Track intermediate adjustment so we can measure how much encoding contributes to the total time
        intermediate_adjust = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        if (last_sent + IDEAL_LENGTH) > now
          sleep_duration = (last_sent + IDEAL_LENGTH - now) / 1000.0
          @bot.debug("Waiting for next frame: #{sleep_duration * 1000}ms (encoding #{intermediate_adjust - start_time}ms)") if @adjust_debug
          sleep sleep_duration if sleep_duration.positive?
        end

        # Send the packet
        @udp.send_audio(buf, @sequence, @time)

        # Set the stream time (for tracking how long we've been playing)
        @stream_time = count * IDEAL_LENGTH / 1000
        last_sent = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      end

      send_silence_frames

      @bot.debug('Performing final cleanup after stream ended')

      # Final clean-up: reset state and notify waiters
      @speaking = false
      @playing = false
      @stop_queue.push(:done)
    end

    # Sends 5 silence frames to clear Discord's audio buffer, then sends Speaking 0.
    # Idempotent: safe to call multiple times.
    def send_silence_frames
      return unless @speaking

      @bot.debug('Sending five silent frames to clear out buffers')

      5.times do
        increment_packet_headers
        @udp.send_audio(Encoder::OPUS_SILENCE, @sequence, @time)
        sleep IDEAL_LENGTH / 1000.0
      end

      self.speaking = false
    end

    # Sends SIGTERM to ffmpeg, waits up to 2 seconds, then SIGKILL as last resort.
    # Always calls waitpid to avoid zombie processes.
    def kill_ffmpeg(io)
      pid = io.pid
      @bot.logger.debug("Killing ffmpeg process with pid #{pid}")

      unless Process.waitpid(pid, Process::WNOHANG).nil?
        @bot.logger.debug("ffmpeg process #{pid} already exited")
        return
      end

      # Try TERM first (works on Unix; Windows uses KILL directly)
      signal = Gem.win_platform? ? 'KILL' : 'TERM'
      Process.kill(signal, pid)

      # Wait up to 2 seconds for graceful shutdown
      unless signal == 'KILL'
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2.0
        while Process.waitpid(pid, Process::WNOHANG).nil?
          break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          sleep 0.05
        end

        # Escalate to KILL if still alive
        if Process.waitpid(pid, Process::WNOHANG).nil?
          @bot.logger.warn("ffmpeg #{pid} did not exit after TERM, sending KILL")
          Process.kill('KILL', pid)
        end
      end

      # Reap the zombie
      Process.waitpid(pid) rescue nil
    rescue StandardError => e
      @bot.logger.warn("Failed to kill ffmpeg process #{pid}: #{e}")
    end

    # Increment sequence (16-bit) and time (32-bit) with proper wrapping
    def increment_packet_headers
      @sequence = (@sequence + 1) & 0xFFFF
      @time = (@time + 960) & 0xFFFFFFFF
    end
  end
end
