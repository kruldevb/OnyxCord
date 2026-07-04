# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # An event for whenever an application command's permissions are updated.
  class ApplicationCommandPermissionsUpdateEvent < Event
    # @return [Integer] the ID of the server where the command permissions were updated.
    attr_reader :server_id

    # @return [Integer, nil] the ID of the application command that was updated.
    attr_reader :command_id

    # @return [Array<ApplicationCommand::Permission>] the permissions that were updated.
    attr_reader :permissions

    # @return [Integer] the ID of the application whose commands were updated.
    attr_reader :application_id

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @server_id = data['guild_id'].to_i
      @application_id = data['application_id'].to_i
      @command_id = data['id'].to_i if data['id'].to_i != @application_id
      @permissions = data['permissions'].map do |permission|
        OnyxCord::ApplicationCommand::Permission.new(permission, data, bot)
      end
    end

    # @return [Server] the server where the command's permissions were updated.
    def server
      @bot.server(@server_id)
    end
  end

  # Event handler for the APPLICATION_COMMAND_PERMISSIONS_UPDATE event.

  # Event handler for the APPLICATION_COMMAND_PERMISSIONS_UPDATE event.
  class ApplicationCommandPermissionsUpdateEventHandler < EventHandler
    # @!visibility private
    def matches?(event)
      return false unless event.is_a?(ApplicationCommandPermissionsUpdateEvent)

      [
        matches_all(@attributes[:server], event.server_id) { |a, e| a.resolve_id == e },
        matches_all(@attributes[:command_id], event.command_id) { |a, e| a.resolve_id == e },
        matches_all(@attributes[:application_id], event.application_id) { |a, e| a.resolve_id == e }
      ].reduce(&:&)
    end
  end
end
