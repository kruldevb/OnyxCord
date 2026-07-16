# frozen_string_literal: true

class OnyxCord::Commands::Bot
  module Channels
    # @see Commands::Bot#update_channels
    def channels=(channels)
      update_channels(channels)
    end

    # Update the list of channels the bot accepts commands from.
    # @param channels [Array<String, Integer, Channel>] The channels this command bot accepts commands on.
    def update_channels(channels = [])
      @attributes[:channels] = Array(channels)
    end

    # Add a channel to the list of channels the bot accepts commands from.
    # @param channel [String, Integer, Channel] The channel name, integer ID, or `Channel` object to be added
    def add_channel(channel)
      channel_id = resolve_channel_id(channel)
      return if @attributes[:channels].any? { |c| resolve_channel_id(c) == channel_id }

      @attributes[:channels] << channel
    end

    # Remove a channel from the list of channels the bot accepts commands from.
    # @param channel [String, Integer, Channel] The channel name, integer ID, or `Channel` object to be removed
    def remove_channel(channel)
      channel_id = resolve_channel_id(channel)
      @attributes[:channels].delete_if { |c| resolve_channel_id(c) == channel_id }
    end

    private

    # Check if the given channel is in the allowed list.
    # Uses Set for O(1) lookup when the list is large.
    def channels?(channel, channels)
      return true if channels.nil? || channels.empty?

      channels.any? do |c|
        if c.is_a?(String)
          c.delete('#') == channel.name ||
            (c.match?(/\A\d+\z/) && c.to_i == channel.resolve_id)
        elsif c.is_a?(Integer)
          c == channel.resolve_id
        else
          resolve_channel_id(c) == channel.resolve_id
        end
      end
    end

    # Resolves a channel identifier to a comparable ID.
    def resolve_channel_id(channel)
      if channel.respond_to?(:resolve_id) && !channel.is_a?(String)
        channel.resolve_id
      else
        channel
      end
    end
  end
end
