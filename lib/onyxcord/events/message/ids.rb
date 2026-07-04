# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # A subset of MessageEvent that only contains a message ID and a channel
  class MessageIDEvent < Event
    include Respondable

    # @return [Integer] the ID associated with this event
    attr_reader :id

    # @return [Server, nil] the server associated with this event
    attr_reader :server

    # @!visibility private
    def initialize(data, bot)
      @id = data['id'].to_i
      @channel = bot.channel(data['channel_id'].to_i)
      @server = @channel.server
      @saved_message = ''
      @bot = bot
    end
  end

  # Event handler for {MessageIDEvent}

  # Event handler for {MessageIDEvent}
  class MessageIDEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? MessageIDEvent

      [
        matches_all(@attributes[:id], event.id) do |a, e|
          a.resolve_id == e.resolve_id
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
        end,
        matches_all(@attributes[:server], event.server) do |a, e|
          a&.resolve_id == e&.resolve_id
        end
      ].reduce(true, &:&)
    end
  end

  # Raised when a message is edited
  # @see OnyxCord::EventContainer#message_edit

  # Raised when a message is deleted
  # @see OnyxCord::EventContainer#message_delete
  class MessageDeleteEvent < MessageIDEvent; end

  # Event handler for {MessageDeleteEvent}

  # Event handler for {MessageDeleteEvent}
  class MessageDeleteEventHandler < MessageIDEventHandler; end

  # Raised whenever a MESSAGE_UPDATE is received
  # @see OnyxCord::EventContainer#message_update
end
