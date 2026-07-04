# frozen_string_literal: true

module OnyxCord
  class Bot
    module Awaits
      # Add an await the bot should listen to. For information on awaits, see {Await}.
      # @param key [Symbol] The key that uniquely identifies the await for {AwaitEvent}s to listen to (see {#await}).
      # @param type [Class] The event class that should be listened for.
      # @param attributes [Hash] The attributes the event should check for. The block will only be executed if all attributes match.
      # @yield Is executed when the await is triggered.
      # @yieldparam event [Event] The event object that was triggered.
      # @return [Await] The await that was created.
      # @deprecated Will be changed to blocking behavior in v4.0. Use {#add_await!} instead.
      def add_await(key, type, attributes = {}, &block)
        raise "You can't await an AwaitEvent!" if type == OnyxCord::Events::AwaitEvent

        await = Await.new(self, key, type, attributes, block)
        @awaits ||= {}
        @awaits[key] = await
      end

      # Awaits an event, blocking the current thread until a response is received.
      # @param type [Class] The event class that should be listened for.
      # @option attributes [Numeric] :timeout the amount of time (in seconds) to wait for a response before returning `nil`. Waits forever if omitted.
      # @yield Executed when a matching event is received.
      # @yieldparam event [Event] The event object that was triggered.
      # @yieldreturn [true, false] Whether the event matches extra await criteria described by the block
      # @return [Event, nil] The event object that was triggered, or `nil` if a `timeout` was set and no event was raised in time.
      # @raise [ArgumentError] if `timeout` is given and is not a positive numeric value
      def add_await!(type, attributes = {})
        raise "You can't await an AwaitEvent!" if type == OnyxCord::Events::AwaitEvent

        timeout = attributes[:timeout]
        raise ArgumentError, 'Timeout must be a number > 0' if timeout.is_a?(Numeric) && !timeout.positive?

        mutex = Mutex.new
        cv = ConditionVariable.new
        response = nil
        block = lambda do |event|
          mutex.synchronize do
            response = event
            if block_given?
              result = yield(event)
              cv.signal if result.is_a?(TrueClass)
            else
              cv.signal
            end
          end
        end

        handler = register_event(type, attributes, block)

        if timeout
          Thread.new do
            sleep timeout
            mutex.synchronize { cv.signal }
          end
        end

        mutex.synchronize { cv.wait(mutex) }

        remove_handler(handler)
        raise 'ConditionVariable was signaled without returning an event!' if response.nil? && timeout.nil?

        response
      end

      # Add a user to the list of ignored users. Those users will be ignored in message events at event processing level.
      # @note Ignoring a user only prevents any message events (including mentions, commands etc.) from them! Typing and
      #   presence and any other events will still be received.
      # @param user [User, String, Integer] The user, or its ID, to be ignored.
      def ignore_user(user)
        @ignored_ids << user.resolve_id
      end

      # Remove a user from the ignore list.
      # @param user [User, String, Integer] The user, or its ID, to be unignored.
      def unignore_user(user)
        @ignored_ids.delete(user.resolve_id)
      end

      # Checks whether a user is being ignored.
      # @param user [User, String, Integer] The user, or its ID, to check.
      # @return [true, false] whether or not the user is ignored.
      def ignored?(user)
        @ignored_ids.include?(user.resolve_id)
      end

      # @see Logger#debug
      def debug(message)
        LOGGER.debug(message)
      end

      # @see Logger#log_exception
      def log_exception(e)
        LOGGER.log_exception(e)
      end

      # Dispatches an event to this bot. Called by the gateway connection handler used internally.
      def dispatch(type, data = nil)
        return dispatch_packet(type) if data.nil? && type.is_a?(Hash)

        handle_dispatch(type, data)
      end

      # Raises a heartbeat event. Called by the gateway connection handler used internally.
      def raise_heartbeat_event
        raise_event(OnyxCord::Events::HeartbeatEvent.new(self))
      end
    end
  end
end
