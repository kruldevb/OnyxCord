# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when somebody reacts to a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :emoji Matches the ID of the emoji that was reacted with, or its name.
    # @option attributes [String, Integer, User] :from Matches the user who added the reaction.
    # @option attributes [String, Integer, Message] :message Matches the message to which the reaction was added.
    # @option attributes [String, Integer, Channel] :in Matches the channel the reaction was added in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of reaction (`:normal` or `:burst`) that was added.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionAddEvent] The event that was raised.
    # @return [ReactionAddEventHandler] The event handler that was registered.
    def reaction_add(attributes = {}, &block)
      register_event(ReactionAddEvent, attributes, block)
    end

    # This **event** is raised when somebody removes a reaction from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :emoji Matches the ID of the emoji that was removed from the reactions, or
    #   its name.
    # @option attributes [String, Integer, User] :from Matches the user who removed the reaction.
    # @option attributes [String, Integer, Message] :message Matches the message to which the reaction was removed.
    # @option attributes [String, Integer, Channel] :in Matches the channel the reaction was removed in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of reaction (`:normal` or `:burst`) that was added.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveEvent] The event that was raised.
    # @return [ReactionRemoveEventHandler] The event handler that was registered.

    # This **event** is raised when somebody removes a reaction from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :emoji Matches the ID of the emoji that was removed from the reactions, or
    #   its name.
    # @option attributes [String, Integer, User] :from Matches the user who removed the reaction.
    # @option attributes [String, Integer, Message] :message Matches the message to which the reaction was removed.
    # @option attributes [String, Integer, Channel] :in Matches the channel the reaction was removed in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of reaction (`:normal` or `:burst`) that was added.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveEvent] The event that was raised.
    # @return [ReactionRemoveEventHandler] The event handler that was registered.
    def reaction_remove(attributes = {}, &block)
      register_event(ReactionRemoveEvent, attributes, block)
    end

    # This **event** is raised when somebody removes all reactions from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Message] :message Matches the message to which the reactions were removed.
    # @option attributes [String, Integer, Channel] :in Matches the channel the reactions were removed in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveAllEvent] The event that was raised.
    # @return [ReactionRemoveAllEventHandler] The event handler that was registered.

    # This **event** is raised when somebody removes all reactions from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Message] :message Matches the message to which the reactions were removed.
    # @option attributes [String, Integer, Channel] :in Matches the channel the reactions were removed in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveAllEvent] The event that was raised.
    # @return [ReactionRemoveAllEventHandler] The event handler that was registered.
    def reaction_remove_all(attributes = {}, &block)
      register_event(ReactionRemoveAllEvent, attributes, block)
    end

    # This **event** is raised when somebody removes all instances of a single reaction from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Message] :message Matches the message where the reaction was removed.
    # @option attributes [String, Integer, Channel] :in Matches the channel where the reaction was removed.
    # @option attributes [String, Integer] :emoji Matches the ID of the emoji that was removed, or its name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveEmojiEvent] The event that was raised.
    # @return [ReactionRemoveEmojiEventHandler] The event handler that was registered.

    # This **event** is raised when somebody removes all instances of a single reaction from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Message] :message Matches the message where the reaction was removed.
    # @option attributes [String, Integer, Channel] :in Matches the channel where the reaction was removed.
    # @option attributes [String, Integer] :emoji Matches the ID of the emoji that was removed, or its name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveEmojiEvent] The event that was raised.
    # @return [ReactionRemoveEmojiEventHandler] The event handler that was registered.
    def reaction_remove_emoji(attributes = {}, &block)
      register_event(ReactionRemoveEmojiEvent, attributes, block)
    end

    # This **event** is raised when a user's status (online/offline/idle) changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose status changed.
    # @option attributes [:offline, :idle, :online] :status Matches the status the user has now.
    # @option attributes [Hash<Symbol, Symbol>] :client_status Matches the current online status (`:online`, `:idle` or `:dnd`) of the user
    #   on various device types (`:desktop`, `:mobile`, or `:web`). The value will be `nil` when the user is offline or invisible
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PresenceEvent] The event that was raised.
    # @return [PresenceEventHandler] the event handler that was registered.
  end
end
