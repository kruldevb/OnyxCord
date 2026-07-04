# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Emoji is created/deleted/updated
  class ServerEmojiChangeEvent < ServerEvent
    # @return [Server] the server in question.
    attr_reader :server

    # @return [Array<Emoji>] array of emojis.
    attr_reader :emoji

    # @!visibility private
    def initialize(server, data, bot)
      @bot = bot
      @server = server
      process_emoji(data)
    end

    # @!visibility private
    def process_emoji(data)
      @emoji = data['emojis'].map do |e|
        @server.emoji[e['id']]
      end
    end
  end

  # Generic event helper for when an emoji is either created or deleted

  # Generic event helper for when an emoji is either created or deleted
  class ServerEmojiCDEvent < ServerEvent
    # @return [Server] the server in question.
    attr_reader :server

    # @return [Emoji] the emoji data.
    attr_reader :emoji

    # @!visibility private
    def initialize(server, emoji, bot)
      @bot = bot
      @emoji = emoji
      @server = server
    end
  end

  # Emoji is created

  # Emoji is created
  class ServerEmojiCreateEvent < ServerEmojiCDEvent; end

  # Emoji is deleted

  # Emoji is deleted
  class ServerEmojiDeleteEvent < ServerEmojiCDEvent; end

  # Emoji is updated

  # Emoji is updated
  class ServerEmojiUpdateEvent < ServerEvent
    # @return [Server] the server in question.
    attr_reader :server

    # @return [Emoji, nil] the emoji data before the event.
    attr_reader :old_emoji

    # @return [Emoji, nil] the updated emoji data.
    attr_reader :emoji

    # @!visibility private
    def initialize(server, old_emoji, emoji, bot)
      @bot = bot
      @old_emoji = old_emoji
      @emoji = emoji
      @server = server
    end
  end

  # Event handler for {ServerEmojiChangeEvent}

  # Event handler for {ServerEmojiChangeEvent}
  class ServerEmojiChangeEventHandler < ServerEventHandler; end

  # Generic handler for emoji create and delete

  # Generic handler for emoji create and delete
  class ServerEmojiCDEventHandler < ServerEventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEmojiCDEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:id], event.emoji.id) { |a, e| a.resolve_id == e.resolve_id },
        matches_all(@attributes[:name], event.emoji.name) { |a, e| a == e }
      ].reduce(true, &:&)
    end
  end

  # Event handler for {ServerEmojiCreateEvent}

  # Event handler for {ServerEmojiCreateEvent}
  class ServerEmojiCreateEventHandler < ServerEmojiCDEventHandler; end

  # Event handler for {ServerEmojiDeleteEvent}

  # Event handler for {ServerEmojiDeleteEvent}
  class ServerEmojiDeleteEventHandler < ServerEmojiCDEventHandler; end

  # Event handler for {ServerEmojiUpdateEvent}

  # Event handler for {ServerEmojiUpdateEvent}
  class ServerEmojiUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEmojiUpdateEvent

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:id], event.old_emoji.id) { |a, e| a.resolve_id == e.resolve_id },
        matches_all(@attributes[:old_name], event.old_emoji.name) { |a, e| a == e },
        matches_all(@attributes[:name], event.emoji.name) { |a, e| a == e }
      ].reduce(true, &:&)
    end
  end

  # Raised whenever an audit log entry is created.
end
