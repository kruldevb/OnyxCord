# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Raised when a channel is deleted
  class ChannelDeleteEvent < Event
    # @return [Integer] the channel's type (0: text, 1: private, 2: voice, 3: group).
    attr_reader :type

    # @return [String] the channel's topic
    attr_reader :topic

    # @return [Integer] the position of the channel on the list
    attr_reader :position

    # @return [String] the channel's name
    attr_reader :name

    # @return [Integer] the channel's ID
    attr_reader :id

    # @return [Server] the channel's server
    attr_reader :server

    # @return [Integer, nil] the channel's owner ID if this is a group channel
    attr_reader :owner_id

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @type = data['type']
      @topic = data['topic']
      @position = data['position']
      @name = data['name']
      @is_private = data['is_private']
      @id = data['id'].to_i
      @server = bot.server(data['guild_id'].to_i) if data['guild_id']
      @owner_id = data['owner_id']&.to_i if @type == 3
    end
  end

  # Event handler for ChannelDeleteEvent

  # Event handler for ChannelDeleteEvent
  class ChannelDeleteEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelDeleteEvent

      [
        matches_all(@attributes[:type], event.type) do |a, e|
          a == case a
               when String, Symbol
                 OnyxCord::Channel::TYPES[a.to_sym]
               else
                 e
               end
        end,
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

  # Generic subclass for recipient events (add/remove)
end
