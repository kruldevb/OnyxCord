# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when a user's status (online/offline/idle) changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose status changed.
    # @option attributes [:offline, :idle, :online] :status Matches the status the user has now.
    # @option attributes [Hash<Symbol, Symbol>] :client_status Matches the current online status (`:online`, `:idle` or `:dnd`) of the user
    #   on various device types (`:desktop`, `:mobile`, or `:web`). The value will be `nil` when the user is offline or invisible
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PresenceEvent] The event that was raised.
    # @return [PresenceEventHandler] the event handler that was registered.
    def presence(attributes = {}, &block)
      register_event(PresenceEvent, attributes, block)
    end

    # This **event** is raised when the game a user is playing changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose playing game changes.
    # @option attributes [String] :game Matches the game the user is now playing.
    # @option attributes [Integer] :type Matches the type of game object (0 game, 1 Twitch stream)
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PlayingEvent] The event that was raised.
    # @return [PlayingEventHandler] the event handler that was registered.

    # This **event** is raised when the game a user is playing changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose playing game changes.
    # @option attributes [String] :game Matches the game the user is now playing.
    # @option attributes [Integer] :type Matches the type of game object (0 game, 1 Twitch stream)
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PlayingEvent] The event that was raised.
    # @return [PlayingEventHandler] the event handler that was registered.
    def playing(attributes = {}, &block)
      register_event(PlayingEvent, attributes, block)
    end

    # This **event** is raised when the bot is mentioned in a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :start_with Matches the string the message starts with.
    # @option attributes [String, Regexp] :end_with Matches the string the message ends with.
    # @option attributes [String, Regexp] :contains Matches a string the message contains.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was sent in.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @option attributes [Integer, String, Symbol] :type Matches the type of the message that was sent.
    # @option attributes [true, false] :role_mention If the event should trigger when the bot's managed role is mentioned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MentionEvent] The event that was raised.
    # @return [MentionEventHandler] the event handler that was registered.
  end
end
