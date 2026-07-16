# frozen_string_literal: true

module OnyxCord
  module Internal
    module RateLimiter
      # Sliding-window limiter for Gateway sends.
      # Uses monotonic clock for drift-free timing.
      class Gateway
        DEFAULT_LIMIT = 120
        DEFAULT_INTERVAL = 60

        def initialize(limit: DEFAULT_LIMIT, interval: DEFAULT_INTERVAL, clock: nil, sleeper: nil)
          @limit = limit
          @interval = interval
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          @sleeper = sleeper || ->(duration) { sleep(duration) }
          @sent_at = []
          @mutex = Mutex.new
        end

        def wait
          @mutex.synchronize do
            now = @clock.call
            prune(now)

            if @sent_at.length >= @limit
              sleep_for = @interval - (now - @sent_at.first)
              @sleeper.call(sleep_for) if sleep_for.positive?
              now = @clock.call
              prune(now)
            end

            @sent_at << now
          end
        end

        # Reset the window — call on new connection
        def reset
          @mutex.synchronize do
            @sent_at.clear
          end
        end

        # Returns seconds until the next send is allowed (0 if ready)
        def wait_time
          @mutex.synchronize do
            now = @clock.call
            prune(now)
            return 0 if @sent_at.length < @limit

            @interval - (now - @sent_at.first)
          end
        end

        private

        def prune(now)
          @sent_at.shift while @sent_at.any? && (now - @sent_at.first) >= @interval
        end
      end
    end
  end
end
