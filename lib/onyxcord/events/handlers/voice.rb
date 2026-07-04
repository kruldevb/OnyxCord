# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when a user's voice state changes. This includes when a user joins, leaves, or
    # moves between voice channels, as well as their mute and deaf status for themselves and on the server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user that raised the event.
    # @option attributes [String, Integer, Channel] :channel Matches the voice channel the user has joined.
    # @option attributes [String, Integer, Channel] :old_channel Matches the voice channel the user was in previously.
    # @option attributes [true, false] :mute Matches whether or not the user is muted server-wide.
    # @option attributes [true, false] :deaf Matches whether or not the user is deafened server-wide.
    # @option attributes [true, false] :self_mute Matches whether or not the user is muted by the bot.
    # @option attributes [true, false] :self_deaf Matches whether or not the user is deafened by the bot.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [VoiceStateUpdateEvent] The event that was raised.
    # @return [VoiceStateUpdateEventHandler] the event handler that was registered.
    def voice_state_update(attributes = {}, &block)
      register_event(VoiceStateUpdateEvent, attributes, block)
    end

    # This **event** is raised when first connecting to a server's voice channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the server that the update is for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [VoiceServerUpdateEvent] The event that was raised.
    # @return [VoiceServerUpdateEventHandler] The event handler that was registered.

    # This **event** is raised when first connecting to a server's voice channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the server that the update is for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [VoiceServerUpdateEvent] The event that was raised.
    # @return [VoiceServerUpdateEventHandler] The event handler that was registered.
    def voice_server_update(attributes = {}, &block)
      register_event(VoiceServerUpdateEvent, attributes, block)
    end

    # This **event** is raised when a new user joins a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the joined user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberAddEvent] The event that was raised.
    # @return [ServerMemberAddEventHandler] the event handler that was registered.
  end
end
