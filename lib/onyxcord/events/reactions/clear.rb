# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Event raised when somebody removes all reactions from a message
  class ReactionRemoveAllEvent < Event
    include Respondable

    # @!visibility private
    attr_reader :message_id

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @message_id = data['message_id'].to_i
      @channel_id = data['channel_id'].to_i
    end

    # @return [Channel] the channel where the removal occurred.
    def channel
      @channel ||= @bot.channel(@channel_id)
    end

    # @return [Message] the message all reactions were removed from.
    def message
      @message ||= channel.load_message(@message_id)
    end
  end

  # Event handler for {ReactionRemoveAllEvent}

  # Event handler for {ReactionRemoveAllEvent}
  class ReactionRemoveAllEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ReactionRemoveAllEvent

      [
        matches_all(@attributes[:message], event.message_id) do |a, e|
          a == e
        end,
        matches_all(@attributes[:in], event.channel) do |a, e|
          case a
          when String
            # Make sure to remove the "#" from channel names in case it was specified
            a.delete('#') == e.name
          when Integer
            a == e.id
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end

  # Event raised when all instances of a single reaction are removed from a message.

  # Event raised when all instances of a single reaction are removed from a message.
  class ReactionRemoveEmojiEvent < ReactionRemoveAllEvent
    # @return [Emoji] the emoji that was removed.
    attr_reader :emoji

    # @!visibility private
    def initialize(data, bot)
      super

      @emoji = OnyxCord::Emoji.new(data['emoji'], bot)
    end
  end

  # Event handler for {ReactionRemoveEmojiEvent}.

  # Event handler for {ReactionRemoveEmojiEvent}.
  class ReactionRemoveEmojiEventHandler < ReactionRemoveAllEventHandler
    # @!visibility private
    def matches?(event)
      # Check for the proper event type.
      return false unless super
      return false unless event.is_a?(ReactionRemoveEmojiEvent)

      [
        matches_all(@attributes[:emoji], event.emoji) do |a, e|
          case a
          when Integer
            e.id == a
          when String
            e.name == a || e.name == a.delete(':') || e.id == a.resolve_id
          else
            e == a
          end
        end
      ].reduce(true, &:&)
    end
  end
end
