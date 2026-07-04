# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Raised when a role is created on a server
  class ServerRoleCreateEvent < Event
    # @return [Role] the role that got created
    attr_reader :role

    # @return [Server] the server on which a role got created
    attr_reader :server

    # @!attribute [r] name
    #   @return [String] this role's name
    #   @see Role#name
    delegate :name, to: :role

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @server = bot.server(data['guild_id'].to_i)
      @role = @server&.role(data['role']['id'].to_i)
    end
  end

  # Event handler for ServerRoleCreateEvent
  class ServerRoleCreateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ServerRoleCreateEvent

      [
        matches_all(@attributes[:name], event.name) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end
      ].reduce(true, &:&)
    end
  end
end
