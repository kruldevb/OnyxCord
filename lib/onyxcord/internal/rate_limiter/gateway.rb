# frozen_string_literal: true

module OnyxCord
  module Internal
    module RateLimiter
      # Sliding-window limiter for Gateway sends.
      class Gateway
        DEFAULT_LIMIT = 120
        DEFAULT_INTERVAL = 60

        def initialize(limit: DEFAULT_LIMIT, interval: DEFAULT_INTERVAL, clock: -> { Time.now }, sleeper: ->(duration) { sleep(duration) })
          @limit = limit
          @interval = interval
          @clock = clock
          @sleeper = sleeper
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

        private

        def prune(now)
          @sent_at.shift while @sent_at.any? && (now - @sent_at.first) >= @interval
        end
      end
    end
  end
end
