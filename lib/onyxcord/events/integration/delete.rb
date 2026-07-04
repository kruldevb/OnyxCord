# frozen_string_literal: true

require 'onyxcord/events/generic'

module OnyxCord::Events
  # Raised whenever an integration is deleted.
  class IntegrationDeleteEvent < Event
    # @return [Server] the server associated with the event.
    attr_reader :server

    # @return [Integer] the ID of the integration that was removed.
    attr_reader :integration_id

    # @return [Integer, nil] the ID of the application that was removed.
    attr_reader :application_id

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @server = bot.server(data['guild_id'].to_i)
      @integration_id = data['id'].to_i
      @application_id = data['application_id']&.to_i
    end
  end

  # Event handler for INTEGRATION_DELETE events.
  class IntegrationDeleteEventHandler < EventHandler
    # @!visibility private
    def matches?(event)
      # Check for the proper event type.
      return false unless event.is_a?(IntegrationDeleteEvent)

      [
        matches_all(@attributes[:server], event.server) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:id], event.integration_id) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:application], event.application_id) do |a, e|
          a&.resolve_id == e&.resolve_id
        end
      ].reduce(true, &:&)
    end
  end
end
