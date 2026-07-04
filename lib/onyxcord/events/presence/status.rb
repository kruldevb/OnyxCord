# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Event raised when a user's presence state updates (idle or online)
  class PresenceEvent < Event
    # @return [Server] the server on which the presence update happened.
    attr_reader :server

    # @return [User] the user whose status got updated.
    attr_reader :user

    # @return [Symbol] the new status.
    attr_reader :status

    # @return [Hash<Symbol, Symbol>] the current online status (`:online`, `:idle` or `:dnd`) of the user
    #   on various device types (`:desktop`, `:mobile`, or `:web`). The value will be `nil` if the user is offline or invisible.
    attr_reader :client_status

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @user = bot.user(data['user']['id'].to_i)
      @status = data['status'].to_sym
      @client_status = user.client_status
      @server = bot.server(data['guild_id'].to_i)
    end
  end

  # Event handler for PresenceEvent
  class PresenceEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? PresenceEvent

      [
        matches_all(@attributes[:from], event.user) do |a, e|
          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:status], event.status) do |a, e|
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
