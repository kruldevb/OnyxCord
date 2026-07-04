# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Event raised when the current bot is mentioned in a message.
  class MentionEvent < MessageEvent
    # @return [true, false] whether this mention event was raised
    #   due to a mention of the bot's auto-generated server role.
    attr_reader :role_mention
    alias_method :role_mention?, :role_mention

    # @!visibility private
    def initialize(message, bot, role_mention)
      super(message, bot)

      @role_mention = role_mention
    end
  end

  # Event handler for {MentionEvent}

  # Event handler for {MentionEvent}
  class MentionEventHandler < MessageEventHandler
    # @!visibility private
    def matches?(event)
      return false unless super
      return false unless event.is_a?(MentionEvent)

      [
        matches_all(@attributes[:role_mention], event.role_mention) do |a, e|
          case a
          when TrueClass
            e == true
          when FalseClass
            e == false
          end
        end
      ].reduce(true, &:&)
    end
  end

  # @see OnyxCord::EventContainer#pm

  # @see OnyxCord::EventContainer#pm
  class PrivateMessageEvent < MessageEvent; end

  # Event handler for {PrivateMessageEvent}

  # Event handler for {PrivateMessageEvent}
  class PrivateMessageEventHandler < MessageEventHandler; end

  # A subset of MessageEvent that only contains a message ID and a channel
end
