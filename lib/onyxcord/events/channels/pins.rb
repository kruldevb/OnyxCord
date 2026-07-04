# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Raised when a message is pinned or unpinned.
  class ChannelPinsUpdateEvent < Event
    # @return [Time, nil] Time at which the most recent pinned message was pinned.
    attr_reader :last_pin_timestamp

    # @return [Channel] The channel this event originates from.
    attr_reader :channel

    # @return [Server, nil] The server this event originates from.
    attr_reader :server

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @server = bot.server(data['guild_id']) if data['guild_id']
      @channel = bot.channel(data['channel_id'])
      @last_pin_timestamp = Time.iso8601(data['last_pin_timestamp']) if data['last_pin_timestamp']
    end
  end

  # Event handler for ChannelPinsUpdateEvent.

  # Event handler for ChannelPinsUpdateEvent.
  class ChannelPinsUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type.
      return false unless event.is_a? ChannelPinsUpdateEvent

      [
        matches_all(@attributes[:server], event.server) { |a, e| a.resolve_id == e&.id },
        matches_all(@attributes[:channel], event.channel) { |a, e| a.resolve_id == e.id }
      ].reduce(true, &:&)
    end
  end

  # Raised when a user is added to a private channel
end
