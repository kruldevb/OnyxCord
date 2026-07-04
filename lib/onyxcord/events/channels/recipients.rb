# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Generic subclass for recipient events (add/remove)
  class ChannelRecipientEvent < Event
    # @return [Channel] the channel in question.
    attr_reader :channel

    delegate :name, :server, :type, :owner_id, :recipients, :topic, :user_limit, :position, :permission_overwrites, to: :channel

    # @return [Recipient] the recipient that was added/removed from the group
    attr_reader :recipient

    delegate :id, to: :recipient

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @channel = bot.channel(data['channel_id'].to_i)
      recipient = data['user']
      recipient_user = bot.ensure_user(recipient)
      @recipient = OnyxCord::Recipient.new(recipient_user, @channel, bot)
    end
  end

  # Generic event handler for channel recipient events

  # Generic event handler for channel recipient events
  class ChannelRecipientEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ChannelRecipientEvent

      [
        matches_all(@attributes[:owner_id], event.owner_id) do |a, e|
          a.resolve_id == e.resolve_id
        end,
        matches_all(@attributes[:id], event.id) do |a, e|
          a.resolve_id == e.resolve_id
        end,
        matches_all(@attributes[:name], event.name) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end
      ]
    end
  end

  # Raised when a message is pinned or unpinned.

  # Raised when a user is added to a private channel
  class ChannelRecipientAddEvent < ChannelRecipientEvent; end

  # Event handler for ChannelRecipientAddEvent

  # Event handler for ChannelRecipientAddEvent
  class ChannelRecipientAddEventHandler < ChannelRecipientEventHandler; end

  # Raised when a recipient that isn't the bot leaves or is kicked from a group channel

  # Raised when a recipient that isn't the bot leaves or is kicked from a group channel
  class ChannelRecipientRemoveEvent < ChannelRecipientEvent; end

  # Event handler for ChannelRecipientRemoveEvent

  # Event handler for ChannelRecipientRemoveEvent
  class ChannelRecipientRemoveEventHandler < ChannelRecipientEventHandler; end

  # Raised when a channel is updated (e.g. topic changes)
end
