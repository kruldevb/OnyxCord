# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when a channel is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being created (0: text, 1: private, 2: voice, 3: group)
    # @option attributes [String] :name Matches the name of the created channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelCreateEvent] The event that was raised.
    # @return [ChannelCreateEventHandler] the event handler that was registered.
    def channel_create(attributes = {}, &block)
      register_event(ChannelCreateEvent, attributes, block)
    end

    # This **event** is raised when a channel is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being updated (0: text, 1: private, 2: voice, 3: group).
    # @option attributes [String] :name Matches the new name of the channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelUpdateEvent] The event that was raised.
    # @return [ChannelUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when a channel is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being updated (0: text, 1: private, 2: voice, 3: group).
    # @option attributes [String] :name Matches the new name of the channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelUpdateEvent] The event that was raised.
    # @return [ChannelUpdateEventHandler] the event handler that was registered.
    def channel_update(attributes = {}, &block)
      register_event(ChannelUpdateEvent, attributes, block)
    end

    # This **event** is raised when a channel is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being deleted (0: text, 1: private, 2: voice, 3: group).
    # @option attributes [String] :name Matches the name of the deleted channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelDeleteEvent] The event that was raised.
    # @return [ChannelDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when a channel is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being deleted (0: text, 1: private, 2: voice, 3: group).
    # @option attributes [String] :name Matches the name of the deleted channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelDeleteEvent] The event that was raised.
    # @return [ChannelDeleteEventHandler] the event handler that was registered.
    def channel_delete(attributes = {}, &block)
      register_event(ChannelDeleteEvent, attributes, block)
    end

    # This **event** is raised when a recipient is added to a group channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the name of the group channel that the recipient is added to.
    # @option attributes [String, Integer] :owner_id Matches the ID of the group channel's owner.
    # @option attributes [String, Integer] :id Matches the ID of the recipient added to the group channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelRecipientAddEvent] The event that was raised.
    # @return [ChannelRecipientAddHandler] the event handler that was registered.

    # This **event** is raised when a recipient is added to a group channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the name of the group channel that the recipient is added to.
    # @option attributes [String, Integer] :owner_id Matches the ID of the group channel's owner.
    # @option attributes [String, Integer] :id Matches the ID of the recipient added to the group channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelRecipientAddEvent] The event that was raised.
    # @return [ChannelRecipientAddHandler] the event handler that was registered.
    def channel_recipient_add(attributes = {}, &block)
      register_event(ChannelRecipientAddEvent, attributes, block)
    end

    # This **event** is raised when a recipient is removed from a group channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the name of the group channel that the recipient is added to.
    # @option attributes [String, Integer] :owner_id Matches the ID of the group channel's owner.
    # @option attributes [String, Integer] :id Matches the ID of the recipient removed from the group channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelRecipientRemoveEvent] The event that was raised.
    # @return [ChannelRecipientRemoveHandler] the event handler that was registered.

    # This **event** is raised when a recipient is removed from a group channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the name of the group channel that the recipient is added to.
    # @option attributes [String, Integer] :owner_id Matches the ID of the group channel's owner.
    # @option attributes [String, Integer] :id Matches the ID of the recipient removed from the group channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelRecipientRemoveEvent] The event that was raised.
    # @return [ChannelRecipientRemoveHandler] the event handler that was registered.
    def channel_recipient_remove(attributes = {}, &block)
      register_event(ChannelRecipientRemoveEvent, attributes, block)
    end

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

    # This **event** is raised whenever a message is pinned or unpinned.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :channel A channel to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelPinsUpdateEvent] The event that was raised.
    # @return [ChannelPinsUpdateEventHandler] The event handler that was registered.
    def channel_pins_update(attributes = {}, &block)
      register_event(ChannelPinsUpdateEvent, attributes, block)
    end

    # This **event** is raised whenever an autocomplete interaction is created.
    # @param name [String, Symbol, nil] An option name to match against.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :command_id A command ID to match against.
    # @option attributes [String, Symbol] :subcommand A subcommand name to match against.
    # @option attributes [String, Symbol] :subcommand_group A subcommand group to match against.
    # @option attributes [String, Symbol] :command_name A command name to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AutocompleteEvent] The event that was raised.
    # @return [AutocompleteEventHandler] The event handler that was registered.
  end
end
