# frozen_string_literal: true

require 'onyxcord/models'
require 'onyxcord/events/generic'

module OnyxCord::Events
  # Generic superclass for integration events.
  class IntegrationEvent < Event
    # @return [Server] the server associated with the event.
    attr_reader :server

    # @return [Integration] the integration associated with the event.
    attr_reader :integration

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @server = bot.server(data['guild_id'].to_i)
      @integration = OnyxCord::Integration.new(data, @bot, @server)
    end
  end

  # Generic event handler for integration events.
  class IntegrationEventHandler < EventHandler
    # @!visibility private
    def matches?(event)
      # Check for the proper event type.
      return false unless event.is_a?(IntegrationEvent)

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:id], event.integration) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:application], event.integration) do |a, e|
          a&.resolve_id == e.application&.resolve_id
        end
      ].reduce(true, &:&)
    end
  end
end
