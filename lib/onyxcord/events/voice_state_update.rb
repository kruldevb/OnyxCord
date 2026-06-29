# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/data'

module OnyxCord::Events
  # Event raised when a user's voice state updates
  class VoiceStateUpdateEvent < Event
    attr_reader :user, :user_id, :token, :suppress, :session_id, :self_mute, :self_deaf, :mute, :deaf, :server, :channel

    # @return [Channel, nil] the old channel this user was on, or nil if the user is newly joining voice.
    attr_reader :old_channel

    # @return [Integer, nil] the current voice channel ID, or nil if the user left voice.
    attr_reader :channel_id

    # @return [Integer, nil] the previous voice channel ID, or nil if the user joined voice.
    attr_reader :old_channel_id

    # @!visibility private
    def initialize(data, old_channel_id, bot)
      @bot = bot

      @token = data['token']
      @suppress = data['suppress']
      @session_id = data['session_id']
      @self_mute = data['self_mute']
      @self_deaf = data['self_deaf']
      @mute = data['mute']
      @deaf = data['deaf']
      @user_id = data['user_id']&.to_i
      @channel_id = data['channel_id']&.to_i
      @old_channel_id = old_channel_id&.to_i
      @server = cached_server(bot, data['guild_id'])
      return unless @server

      @channel = cached_channel(bot, @channel_id, @server)
      @old_channel = cached_channel(bot, @old_channel_id, @server)
      @user = cached_user(bot, data)
    end

    def cached_server(bot, server_id)
      servers = bot.instance_variable_get(:@servers)
      servers&.[](server_id.to_i)
    end

    def cached_channel(bot, channel_id, server)
      return nil unless channel_id

      channels = bot.instance_variable_get(:@channels)
      channels&.[](channel_id.to_i) || server.channels.find { |channel| channel.id == channel_id.to_i }
    end

    def cached_user(bot, data)
      user_data = data.dig('member', 'user') || data['user']
      return bot.ensure_user(user_data) if user_data

      users = bot.instance_variable_get(:@users)
      users&.[](data['user_id'].to_i)
    end
  end

  # Event handler for VoiceStateUpdateEvent
  class VoiceStateUpdateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? VoiceStateUpdateEvent

      [
        matches_all(@attributes[:from], event.user) do |a, e|
          next unless e

          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:mute], event.mute) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:deaf], event.deaf) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:self_mute], event.self_mute) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:self_deaf], event.self_deaf) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:channel], event.channel) do |a, e|
          next unless e # Don't bother if the channel is nil

          a == case a
               when String
                 e.name
               when Integer
                 e.id
               else
                 e
               end
        end,
        matches_all(@attributes[:old_channel], event.old_channel) do |a, e|
          next unless e # Don't bother if the channel is nil

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
