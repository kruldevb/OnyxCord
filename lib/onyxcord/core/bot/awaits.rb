# frozen_string_literal: true

module OnyxCord
  class Bot
    module Awaits
      # @deprecated Will be changed to blocking behavior in v4.0. Use {#add_await!} instead.
      def add_await(key, type, attributes = {}, reusable: false, &block)
        raise "You can't await an AwaitEvent!" if type == OnyxCord::Events::AwaitEvent

        await = Await.new(self, key, type, attributes, block, reusable: reusable)
        @awaits ||= {}
        @awaits[key] = await
      end

      # Removes a non-blocking await by its key.
      # @param key [Symbol] The key of the await to remove.
      # @return [true, false] whether the await was found and removed.
      def cancel_await(key)
        return false unless @awaits&.key?(key)

        @awaits.delete(key)
        true
      end

      private

      def add_await!(type, attributes = {}, &block)
        raise "You can't await an AwaitEvent!" if type == OnyxCord::Events::AwaitEvent

        timeout = attributes[:timeout]
        validate_await_timeout!(timeout)

        mutex = Mutex.new
        cv = ConditionVariable.new
        response = nil
        done = false

        event_block = lambda do |event|
          matched = block_given? ? block.call(event) : true
          return unless matched

          mutex.synchronize do
            unless done
              done = true
              response = event
              cv.signal
            end
          end
        end

        handler = register_event(type, attributes, event_block)

        if timeout
          Thread.new do
            sleep timeout
            mutex.synchronize do
              unless done
                done = true
                cv.signal
              end
            end
          end
        end

        mutex.synchronize { cv.wait(mutex) }

        remove_handler(handler)

        raise 'ConditionVariable was signaled without returning an event!' if response.nil? && timeout.nil?

        response
      end

      def ignore_user(user)
        @ignored_ids << user.resolve_id
      end

      def unignore_user(user)
        @ignored_ids.delete(user.resolve_id)
      end

      def ignored?(user)
        @ignored_ids.include?(user.resolve_id)
      end

      def debug(message)
        LOGGER.debug(message)
      end

      def log_exception(e)
        LOGGER.log_exception(e)
      end

      def dispatch(type, data = nil)
        return dispatch_packet(type) if data.nil? && type.is_a?(Hash)

        handle_dispatch(type, data)
      end

      def raise_heartbeat_event
        raise_event(OnyxCord::Events::HeartbeatEvent.new(self))
      end

      def validate_await_timeout!(timeout)
        return if timeout.nil?
        return if timeout.is_a?(Numeric) && timeout.finite? && timeout.positive?

        raise ArgumentError, "Invalid await timeout: #{timeout.inspect}. Must be nil or a finite positive Numeric."
      end
    end
  end
end
