# frozen_string_literal: true

module OnyxCord
  class Bot
    module VoiceControl
      # @return [Hash<Integer => Client>] the voice connections this bot currently has, by the server ID to which they are connected.
      attr_reader :voices

      # Gets the voice bot for a particular server or channel. You can connect to a new channel using the {#voice_connect}
      # method.
      # @param thing [Channel, Server, Integer] the server or channel you want to get the voice bot for, or its ID.
      # @return [Voice::Client, nil] the Client for the thing you specified, or nil if there is no connection yet
      def voice(thing)
        id = thing.resolve_id
        return @voices[id] if @voices[id]

        channel = channel(id)
        return nil unless channel

        server_id = channel.server.id
        return @voices[server_id] if @voices[server_id]
      end

      # Connects to a voice channel, initializes network connections and returns the {Voice::Client} over which audio
      # data can then be sent. After connecting, the bot can also be accessed using {#voice}. If the bot is already
      # connected to voice, the existing connection will be terminated - you don't have to call
      # {OnyxCord::Voice::Client#destroy} before calling this method.
      # @param chan [Channel, String, Integer] The voice channel, or its ID, to connect to.
      # @param encrypted [true, false] Whether voice communication should be encrypted using
      #   (uses an XSalsa20 stream cipher for encryption and Poly1305 for authentication)
      # @return [Voice::Client] the initialized bot over which audio data can then be sent.
      def voice_connect(chan, encrypted = true)
        raise ArgumentError, 'Unencrypted voice connections are no longer supported.' unless encrypted

        chan = channel(chan.resolve_id)
        server_id = chan.server.id

        if @voices[chan.id]
          debug('Voice bot exists already! Destroying it')
          @voices[chan.id].destroy
          @voices.delete(chan.id)
        end

        debug("Got voice channel: #{chan}")

        @should_connect_to_voice[server_id] = chan
        @gateway.send_voice_state_update(server_id.to_s, chan.id.to_s, false, false)

        debug('Voice channel init packet sent! Now waiting.')

        Internal::AsyncRuntime.sleep(0.05) until @voices[server_id]
        debug('Voice connect succeeded!')
        @voices[server_id]
      end

      # Disconnects the client from a specific voice connection given the server ID. Usually it's more convenient to use
      # {OnyxCord::Voice::Client#destroy} rather than this.
      # @param server [Server, String, Integer] The server, or server ID, the voice connection is on.
      # @param destroy_vws [true, false] Whether or not the VWS should also be destroyed. If you're calling this method
      #   directly, you should leave it as true.
      def voice_destroy(server, destroy_vws = true)
        server = server.resolve_id
        @gateway.send_voice_state_update(server.to_s, nil, false, false)
        @voices[server].destroy if @voices[server] && destroy_vws
        @voices.delete(server)
      end
    end
  end
end
