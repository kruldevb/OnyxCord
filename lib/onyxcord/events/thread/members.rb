# frozen_string_literal: true

require 'onyxcord/events/thread/base'

module OnyxCord::Events
  # Raised when members are added or removed from a thread.
  class ThreadMembersUpdateEvent < Event
    # @return [Channel]
    attr_reader :thread

    # @return [Array<Integer>]
    attr_reader :removed_member_ids

    # @return [Integer]
    attr_reader :member_count

    delegate :name, :server, :owner, :parent_channel, :thread_metadata, to: :thread

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @server = bot.server(data['guild_id'].to_i) if data['guild_id']
      @thread = data.is_a?(OnyxCord::Channel) ? data : bot.channel(data['id'].to_i)
      @added_member_ids = data['added_members']&.map { |m| m['user_id']&.to_i } || []
      @removed_member_ids = data['removed_member_ids']&.map(&:resolve_id) || []
      @member_count = data['member_count']
    end
  end

  # @return [Array<Member, User>] the members that were added to the thread
  def added_members
    @added_members ||= @added_member_ids&.map { |id| @server&.member(id) || @bot.user(id) }
  end

  # Event handler for ThreadMembersUpdateEvent
  class ThreadMembersUpdateEventHandler < ThreadCreateEventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ThreadMembersUpdateEvent

      super
    end
  end
end
