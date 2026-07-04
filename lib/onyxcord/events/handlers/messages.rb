# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when a message is sent to a text channel the bot is currently in.
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
    # @option attributes [Server, Integer, String] :server Matches the server the message was sent in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEvent] The event that was raised.
    # @return [MessageEventHandler] the event handler that was registered.
    def message(attributes = {}, &block)
      register_event(MessageEvent, attributes, block)
    end

    # This **event** is raised when the READY packet is received, i.e. servers and channels have finished
    # initialization. It's the recommended way to do things when the bot has finished starting up.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReadyEvent] The event that was raised.
    # @return [ReadyEventHandler] the event handler that was registered.

    # This **event** is raised when somebody starts typing in a channel the bot is also in. The official Discord
    # client would display the typing indicator for five seconds after receiving this event. If the user continues
    # typing after five seconds, the event will be re-raised.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :in Matches the channel where typing was started.
    # @option attributes [String, Integer, User] :from Matches the user that started typing.
    # @option attributes [Time] :after Matches a time after the time the typing started.
    # @option attributes [Time] :before Matches a time before the time the typing started.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [TypingEvent] The event that was raised.
    # @return [TypingEventHandler] the event handler that was registered.
    def typing(attributes = {}, &block)
      register_event(TypingEvent, attributes, block)
    end

    # This **event** is raised when a message is edited in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the ID of the message that was edited.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was edited in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of the message that was edited.
    # @option attributes [Server, Integer, String] :server Matches the server the message was edited in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEditEvent] The event that was raised.
    # @return [MessageEditEventHandler] the event handler that was registered.

    # This **event** is raised when a message is edited in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the ID of the message that was edited.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was edited in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of the message that was edited.
    # @option attributes [Server, Integer, String] :server Matches the server the message was edited in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEditEvent] The event that was raised.
    # @return [MessageEditEventHandler] the event handler that was registered.
    def message_edit(attributes = {}, &block)
      register_event(MessageEditEvent, attributes, block)
    end

    # This **event** is raised when a message is deleted in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the ID of the message that was deleted.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was deleted in.
    # @option attributes [Server, Integer, String] :server Matches the server the message was deleted in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageDeleteEvent] The event that was raised.
    # @return [MessageDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when a message is deleted in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the ID of the message that was deleted.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was deleted in.
    # @option attributes [Server, Integer, String] :server Matches the server the message was deleted in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageDeleteEvent] The event that was raised.
    # @return [MessageDeleteEventHandler] the event handler that was registered.
    def message_delete(attributes = {}, &block)
      register_event(MessageDeleteEvent, attributes, block)
    end

    # This **event** is raised whenever a message is updated. Message updates can be triggered from
    # a user editing their own message, or from Discord automatically attaching embeds to the
    # user's message for URLs contained in the message's content. If you only want to listen
    # for users editing their own messages, use the {message_edit} handler instead.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the ID of the message that was updated.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was updated in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of the message that was updated.
    # @option attributes [Server, Integer, String] :server Matches the server the message was updated in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageUpdateEvent] The event that was raised.
    # @return [MessageUpdateEventHandler] the event handler that was registered.

    # This **event** is raised whenever a message is updated. Message updates can be triggered from
    # a user editing their own message, or from Discord automatically attaching embeds to the
    # user's message for URLs contained in the message's content. If you only want to listen
    # for users editing their own messages, use the {message_edit} handler instead.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the ID of the message that was updated.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was updated in.
    # @option attributes [Integer, String, Symbol] :type Matches the type of the message that was updated.
    # @option attributes [Server, Integer, String] :server Matches the server the message was updated in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageUpdateEvent] The event that was raised.
    # @return [MessageUpdateEventHandler] the event handler that was registered.
    def message_update(attributes = {}, &block)
      register_event(MessageUpdateEvent, attributes, block)
    end

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
    def mention(attributes = {}, &block)
      register_event(MentionEvent, attributes, block)
    end

    # This **event** is raised when a channel is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being created (0: text, 1: private, 2: voice, 3: group)
    # @option attributes [String] :name Matches the name of the created channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelCreateEvent] The event that was raised.
    # @return [ChannelCreateEventHandler] the event handler that was registered.

    # This **event** is raised when a private message is sent to the bot.
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
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PrivateMessageEvent] The event that was raised.
    # @return [PrivateMessageEventHandler] the event handler that was registered.
    def pm(attributes = {}, &block)
      register_event(PrivateMessageEvent, attributes, block)
    end

    alias_method :private_message, :pm
    alias_method :direct_message, :pm
    alias_method :dm, :pm

    # This **event** is raised when an invite is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :inviter Matches the user that created the invite.
    # @option attributes [String, Integer, Channel] :channel Matches the channel the invite was created for.
    # @option attributes [String, Integer, Server] :server Matches the server the invite was created for.
    # @option attributes [true, false] :temporary Matches whether the invite is temporary or not.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [InviteCreateEvent] The event that was raised.
    # @return [InviteCreateEventHandler] The event handler that was registered.

    # This **event** is raised when an {Await} is triggered. It provides an easy way to execute code
    # on an await without having to rely on the await's block.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Symbol] :key Exactly matches the await's key.
    # @option attributes [Class] :type Exactly matches the event's type.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AwaitEvent] The event that was raised.
    # @return [AwaitEventHandler] the event handler that was registered.
    def await(attributes = {}, &block)
      register_event(AwaitEvent, attributes, block)
    end

    # This **event** is raised when a private message is sent to the bot.
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
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PrivateMessageEvent] The event that was raised.
    # @return [PrivateMessageEventHandler] the event handler that was registered.
  end
end
