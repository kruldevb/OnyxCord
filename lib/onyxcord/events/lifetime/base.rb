# frozen_string_literal: true

require 'onyxcord/events/generic'

module OnyxCord::Events
  # Common superclass for all lifetime events
  class LifetimeEvent < Event
    # @!visibility private
    def initialize(bot)
      @bot = bot
    end
  end

  # @see OnyxCord::EventContainer#ready
  class ReadyEvent < LifetimeEvent; end

  # Event handler for {ReadyEvent}
  class ReadyEventHandler < TrueEventHandler; end

  # @see OnyxCord::EventContainer#disconnected
  class DisconnectEvent < LifetimeEvent; end

  # Event handler for {DisconnectEvent}
  class DisconnectEventHandler < TrueEventHandler; end

  # @see OnyxCord::EventContainer#heartbeat
  class HeartbeatEvent < LifetimeEvent; end

  # Event handler for {HeartbeatEvent}
  class HeartbeatEventHandler < TrueEventHandler; end
end
