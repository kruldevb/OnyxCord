# frozen_string_literal: true

require 'onyxcord/events/generic'

module OnyxCord::Events
  # Raised when an invite is deleted.
  class InviteDeleteEvent < Event
    # @return [Channel] The channel the deleted invite was for.
    attr_reader :channel

    # @return [Server, nil] The server the deleted invite was for.
    attr_reader :server

    # @return [String] The code of the deleted invite.
    attr_reader :code

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @channel = bot.channel(data['channel_id'])
      @server = bot.server(data['guild_id']) if data['guild_id']
      @code = data['code']
    end
  end

  # Event handler for InviteDeleteEvent
  class InviteDeleteEventHandler < EventHandler
    def matches?(event)
      return false unless event.is_a? InviteDeleteEvent

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
        matches_all(@attributes[:channel], event.channel) do |a, e|
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
end
