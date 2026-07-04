# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when the READY packet is received, i.e. servers and channels have finished
    # initialization. It's the recommended way to do things when the bot has finished starting up.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReadyEvent] The event that was raised.
    # @return [ReadyEventHandler] the event handler that was registered.
    def ready(attributes = {}, &block)
      register_event(ReadyEvent, attributes, block)
    end

    # This **event** is raised when the bot has disconnected from the WebSocket, due to the {Bot#stop} method or
    # external causes. It's the recommended way to do clean-up tasks.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [DisconnectEvent] The event that was raised.
    # @return [DisconnectEventHandler] the event handler that was registered.

    # This **event** is raised when the bot has disconnected from the WebSocket, due to the {Bot#stop} method or
    # external causes. It's the recommended way to do clean-up tasks.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [DisconnectEvent] The event that was raised.
    # @return [DisconnectEventHandler] the event handler that was registered.
    def disconnected(attributes = {}, &block)
      register_event(DisconnectEvent, attributes, block)
    end

    # This **event** is raised every time the bot sends a heartbeat over the galaxy. This happens roughly every 40
    # seconds, but may happen at a lower rate should Discord change their interval. It may also happen more quickly for
    # periods of time, especially for unstable connections, since onyxcord rather sends a heartbeat than not if there's
    # a choice. (You shouldn't rely on all this to be accurately timed.)
    #
    # All this makes this event useful to periodically trigger something, like doing some API request every hour,
    # setting some kind of uptime variable or whatever else. The only limit is yourself.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [HeartbeatEvent] The event that was raised.
    # @return [HeartbeatEventHandler] the event handler that was registered.

    # This **event** is raised every time the bot sends a heartbeat over the galaxy. This happens roughly every 40
    # seconds, but may happen at a lower rate should Discord change their interval. It may also happen more quickly for
    # periods of time, especially for unstable connections, since onyxcord rather sends a heartbeat than not if there's
    # a choice. (You shouldn't rely on all this to be accurately timed.)
    #
    # All this makes this event useful to periodically trigger something, like doing some API request every hour,
    # setting some kind of uptime variable or whatever else. The only limit is yourself.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [HeartbeatEvent] The event that was raised.
    # @return [HeartbeatEventHandler] the event handler that was registered.
    def heartbeat(attributes = {}, &block)
      register_event(HeartbeatEvent, attributes, block)
    end

    # This **event** is raised when somebody starts typing in a channel the bot is also in. The official Discord
    # client would display the typing indicator for five seconds after receiving this event. If the user continues
    # typing after five seconds, the event will be re-raised.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :in Matches the channel where typing was started.
    # @option attributes [String, Integer, User] :from Matches the user that started typing.
    # @option attributes [Time] :after Matches a time after the time the typing started.
    # @option attributes [Time] :before Matches a time before the time the typing started.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [TypingEvent] The event that was raised.
    # @return [TypingEventHandler] the event handler that was registered.
  end
end
