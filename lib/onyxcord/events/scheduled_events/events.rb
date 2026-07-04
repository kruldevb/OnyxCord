# frozen_string_literal: true

require 'onyxcord/models'
require 'onyxcord/events/generic'

module OnyxCord::Events
  # Generic superclass for scheduled events.
  class ScheduledEventEvent < Event
    # @return [Server] the server associated with the event.
    attr_reader :server

    # @return [ScheduledEvent] the scheduled event associated with the event.
    attr_reader :scheduled_event

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @server = bot.server(data['guild_id'].to_i)
      @scheduled_event = @server&.scheduled_event(data['id'].to_i)
    end
  end

  # Raised whenever a scheduled event is created.

  # Raised whenever a scheduled event is created.
  class ScheduledEventCreateEvent < ScheduledEventEvent; end

  # Raised whenever a scheduled event is updated.

  # Raised whenever a scheduled event is updated.
  class ScheduledEventUpdateEvent < ScheduledEventEvent; end

  # Raised whenever a scheduled event is deleted.

  # Raised whenever a scheduled event is deleted.
  class ScheduledEventDeleteEvent < ScheduledEventEvent
    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @server = bot.server(data['guild_id'].to_i)
      @scheduled_event = OnyxCord::ScheduledEvent.new(data, @server, @bot)
    end
  end

  # Generic superclass for scheduled event user events.

  # Generic event handler for scheduled event.
  class ScheduledEventEventHandler < EventHandler
    # @!visibility private
    def matches?(event)
      # Check for the proper event type.
      return false unless event.is_a?(ScheduledEventEvent)

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:id], event.scheduled_event) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:creator], event.scheduled_event.creator) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:channel], event.scheduled_event.channel) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:entity_id], event.scheduled_event.entity_id) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:entity_type], event.scheduled_event.entity_type) do |a, e|
          case a
          when Symbol, String
            OnyxCord::ScheduledEvent::ENTITY_TYPES[a.to_sym] == e
          else
            a == e
          end
        end,

        matches_all(@attributes[:status], event.scheduled_event.status) do |a, e|
          case a
          when Symbol, String
            OnyxCord::ScheduledEvent::STATUSES[a.to_sym] == e
          else
            a == e
          end
        end
      ].reduce(true, &:&)
    end
  end

  # Event handler for :GUILD_SCHEDULED_EVENT_CREATE events.

  # Event handler for :GUILD_SCHEDULED_EVENT_CREATE events.
  class ScheduledEventCreateEventHandler < ScheduledEventEventHandler; end

  # Event handler for :GUILD_SCHEDULED_EVENT_UPDATE events.

  # Event handler for :GUILD_SCHEDULED_EVENT_UPDATE events.
  class ScheduledEventUpdateEventHandler < ScheduledEventEventHandler; end

  # Event handler for :GUILD_SCHEDULED_EVENT_DELETE events.

  # Event handler for :GUILD_SCHEDULED_EVENT_DELETE events.
  class ScheduledEventDeleteEventHandler < ScheduledEventEventHandler; end

  # Generic event handler for scheduled event user events.
end
