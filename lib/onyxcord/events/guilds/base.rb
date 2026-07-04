# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Generic subclass for server events (create/update/delete)
  class ServerEvent < Event
    # @return [Server] the server in question.
    attr_reader :server

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      init_server(data, bot)
    end

    # Initializes this event with server data. Should be overwritten in case the server doesn't exist at the time
    # of event creation (e. g. {ServerDeleteEvent})
    def init_server(data, bot)
      @server = bot.server(data['id'].to_i)
    end
  end

  # Generic event handler for member events

  # Generic event handler for member events
  class ServerEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerEvent

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
        end
      ].reduce(true, &:&)
    end
  end

  # Server is created
  # @see OnyxCord::EventContainer#server_create

  # Server is created
  # @see OnyxCord::EventContainer#server_create
  class ServerCreateEvent < ServerEvent; end

  # Event handler for {ServerCreateEvent}

  # Event handler for {ServerCreateEvent}
  class ServerCreateEventHandler < ServerEventHandler; end

  # Server is updated (e.g. name changed)
  # @see OnyxCord::EventContainer#server_update

  # Server is updated (e.g. name changed)
  # @see OnyxCord::EventContainer#server_update
  class ServerUpdateEvent < ServerEvent; end

  # Event handler for {ServerUpdateEvent}

  # Event handler for {ServerUpdateEvent}
  class ServerUpdateEventHandler < ServerEventHandler; end

  # Server is deleted, the server was left because the bot was kicked, or the
  # bot made itself leave the server.
  # @see OnyxCord::EventContainer#server_delete

  # Server is deleted, the server was left because the bot was kicked, or the
  # bot made itself leave the server.
  # @see OnyxCord::EventContainer#server_delete
  class ServerDeleteEvent < ServerEvent
    # @return [Integer] The ID of the server that was left.
    attr_reader :server

    # @!visibility private
    # @note Override init_server to account for the deleted server
    def init_server(data, _bot)
      @server = data['id'].to_i
    end
  end

  # Event handler for {ServerDeleteEvent}

  # Event handler for {ServerDeleteEvent}
  class ServerDeleteEventHandler < ServerEventHandler; end

  # Emoji is created/deleted/updated
end
