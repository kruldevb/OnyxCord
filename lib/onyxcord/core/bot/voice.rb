# frozen_string_literal: true

module OnyxCord
  class Bot
    module VoiceControl
      VOICE_CONNECT_TIMEOUT = 15

      # @return [Hash<Integer => Client>] the voice connections this bot currently has, by the server ID.
      attr_reader :voices

      # Gets the voice bot for a particular server or channel.
      # @param thing [Channel, Server, Integer] the server or channel you want to get the voice bot for, or its ID.
      # @return [Voice::Client, nil] the Client for the thing you specified, or nil if there is no connection yet
      def voice(thing)
        id = thing.resolve_id
        result = @voices_mutex.synchronize { @voices[id] }
        return result if result

        channel = channel(id)
        return nil unless channel

        server_id = channel.server.id
        @voices_mutex.synchronize { @voices[server_id] }
      end

      # Connects to a voice channel. Destroys any existing connection for the server.
      # @param chan [Channel, String, Integer] The voice channel, or its ID, to connect to.
      # @param encrypted [true, false] Whether voice communication should be encrypted.
      # @return [Voice::Client] the initialized bot over which audio data can then be sent.
      # @raise [RuntimeError] if the connection times out
      def voice_connect(chan, encrypted = true)
        raise ArgumentError, 'Unencrypted voice connections are no longer supported.' unless encrypted

        chan = channel(chan.resolve_id)
        server_id = chan.server.id

        # Destroy existing connection for this server (correct key: server_id, not chan.id)
        @voices_mutex.synchronize do
          existing = @voices[server_id]
          if existing
            debug('Voice bot exists already! Destroying it')
            existing.destroy
            @voices.delete(server_id)
          end
        end

        debug("Got voice channel: #{chan}")

        @should_connect_voice_mutex.synchronize { @should_connect_to_voice[server_id] = chan }
        @gateway.send_voice_state_update(server_id.to_s, chan.id.to_s, false, false)

        debug('Voice channel init packet sent! Now waiting.')

        # Wait with timeout using monotonic clock
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + VOICE_CONNECT_TIMEOUT
        loop do
          voice_client = @voices_mutex.synchronize { @voices[server_id] }
          break voice_client if voice_client

          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if remaining <= 0
            @should_connect_voice_mutex.synchronize { @should_connect_to_voice.delete(server_id) }
            raise "Voice connection timed out after #{VOICE_CONNECT_TIMEOUT}s for server #{server_id}"
          end

          sleep [0.05, remaining].min
        end
      end

      # Disconnects the client from a specific voice connection.
      # @param server [Server, String, Integer] The server, or server ID.
      # @param destroy_vws [true, false] Whether or not the VWS should also be destroyed.
      def voice_destroy(server, destroy_vws = true)
        server = server.resolve_id
        @gateway.send_voice_state_update(server.to_s, nil, false, false)
        @voices_mutex.synchronize do
          @voices[server].destroy if @voices[server] && destroy_vws
          @voices.delete(server)
        end
      end

      # Destroys all voice connections. Called during shutdown.
      def destroy_all_voices
        snapshots = @voices_mutex.synchronize { @voices.values.dup }
        snapshots.each do |client|
          client.destroy
        rescue StandardError => e
          debug("Error destroying voice client: #{e.message}")
        end
        @voices_mutex.synchronize { @voices.clear }
      end
    end
  end
end
