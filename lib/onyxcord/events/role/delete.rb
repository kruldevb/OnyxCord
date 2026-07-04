# frozen_string_literal: true

require 'onyxcord/events/generic'

module OnyxCord::Events
  # Raised when a role is deleted from a server
  class ServerRoleDeleteEvent < Event
    # @return [Integer] the ID of the role that got deleted.
    attr_reader :id

    # @return [Server] the server on which a role got deleted.
    attr_reader :server

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      # The role should already be deleted from the server's list
      # by the time we create this event, so we'll create a temporary
      # role object for event consumers to use.
      @id = data['role_id'].to_i
      server_id = data['guild_id'].to_i
      @server = bot.server(server_id)
    end
  end

  # EventHandler for ServerRoleDeleteEvent
  class ServerRoleDeleteEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerRoleDeleteEvent

      [
        matches_all(@attributes[:id], event.id) do |a, e|
          a.resolve_id == e.resolve_id
        end
      ].reduce(true, &:&)
    end
  end
end
