# frozen_string_literal: true

require 'onyxcord/events/thread/base'

module OnyxCord::Events
  # Raised when a thread is updated (e.g. name changes)
  class ThreadUpdateEvent < ThreadCreateEvent; end

  # Event handler for ThreadUpdateEvent
  class ThreadUpdateEventHandler < ThreadCreateEventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ThreadUpdateEvent

      super
    end
  end
end
