# frozen_string_literal: true

require 'onyxcord/events/generic'

module OnyxCord::Events
  # Raised when a thread is created
  class ThreadCreateEvent < Event
    # @return [Channel] the thread in question.
    attr_reader :thread

    delegate :name, :server, :owner, :parent_channel, :thread_metadata, to: :thread

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @thread = data.is_a?(OnyxCord::Channel) ? data : bot.channel(data['id'].to_i)
    end
  end

  # Event handler for ThreadCreateEvent
  class ThreadCreateEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ThreadCreateEvent

      [
        matches_all(@attributes[:name], event.name) do |a, e|
          a == if a.is_a? String
                 e.to_s
               else
                 e
               end
        end,
        matches_all(@attributes[:server], event.server) do |a, e|
          a.resolve_id == e.resolve_id
        end,
        matches_all(@attributes[:invitable], event.thread.invitable) do |a, e|
          a == e
        end,
        matches_all(@attributes[:owner], event.thread.owner) do |a, e|
          a.resolve_id == e.resolve_id
        end,
        matches_all(@attributes[:channel], event.thread.parent) do |a, e|
          a.resolve_id == e.resolve_id
        end
      ].reduce(true, &:&)
    end
  end
end
