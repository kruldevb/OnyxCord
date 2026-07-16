# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Raised when a channel is created
  class ChannelCreateEvent < Event
    # @return [Channel] the channel in question.
    attr_reader :channel

    # @!attribute [r] type
    #   @return [Integer] the channel's type (0: text, 1: private, 2: voice, 3: group).
    #   @see Channel#type
    # @!attribute [r] topic
    #   @return [String] the channel's topic.
    #   @see Channel#topic
    # @!attribute [r] position
    #   @return [Integer] the position of the channel in the channels list.
    #   @see Channel#position
    # @!attribute [r] name
    #   @return [String] the channel's name
    #   @see Channel#name
    # @!attribute [r] id
    #   @return [Integer] the channel's unique ID.
    #   @see Channel#id
    # @!attribute [r] server
    #   @return [Server] the server the channel belongs to.
    #   @see Channel#server
    delegate :name, :server, :type, :owner_id, :recipients, :topic, :user_limit, :position, :permission_overwrites, to: :channel

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @channel = if data.is_a?(OnyxCord::Channel)
                   data
                 else
                   cached_channel(bot, data['id']) || OnyxCord::Channel.new(data, bot, cached_server(bot, data['guild_id']))
                 end
    end

    def cached_channel(bot, channel_id)
      channels = bot.instance_variable_get(:@channels)
      channels&.[](channel_id.to_i)
    end

    def cached_server(bot, server_id)
      return nil unless server_id

      servers = bot.instance_variable_get(:@servers)
      servers&.[](server_id.to_i)
    end
  end

  # Event handler for ChannelCreateEvent

  # Event handler for ChannelCreateEvent
  class ChannelCreateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelCreateEvent

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

  # Raised when a channel is deleted

  # Raised when a channel is updated (e.g. topic changes)
  class ChannelUpdateEvent < ChannelCreateEvent; end

  # Event handler for ChannelUpdateEvent

  # Event handler for ChannelUpdateEvent
  class ChannelUpdateEventHandler < ChannelCreateEventHandler; end
end
