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
      return if @attributes[:channels].find { |c| channel.resolve_id == c.resolve_id }

      @attributes[:channels] << channel
    end

    # Remove a channel from the list of channels the bot accepts commands from.
    # @param channel [String, Integer, Channel] The channel name, integer ID, or `Channel` object to be removed

    def remove_channel(channel)
      @attributes[:channels].delete_if { |c| channel.resolve_id == c.resolve_id }
    end

    private

    # Internal handler for MESSAGE_CREATE that is overwritten to allow for command handling

    def channels?(channel, channels)
      return true if channels.nil? || channels.empty?

      channels.any? do |c|
        # if c is string, make sure to remove the "#" from channel names in case it was specified
        return true if c.is_a?(String) && c.delete('#') == channel.name

        c.resolve_id == channel.resolve_id
      end
    end
  end
end
