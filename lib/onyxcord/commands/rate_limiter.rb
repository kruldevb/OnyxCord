# frozen_string_literal: true

module OnyxCord::Commands
  # Injectable clock for monotonic time. Use FakeClock in tests.
  class MonotonicClock
    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # Compact entry for rate limiting state per key.
  Entry = Struct.new(:last_time, :set_time, :count)

  # This class represents a bucket for rate limiting - it keeps track of how many requests have been made and when
  # exactly the user should be rate limited.
  #
  # == Algorithm Specification
  # - Uses a fixed window per key: window starts at +set_time+ and lasts +time_span+ seconds.
  # - When +count + increment > limit+ and the window has NOT expired: returns remaining wait time. Does NOT update last_time or count.
  # - When +count + increment > limit+ and the window HAS expired: resets the window (set_time = now, count = 0) and falls through to delay check.
  # - Delay check: if +now < last_time + delay+, returns remaining wait time. Does NOT consume count.
  # - Otherwise: updates last_time, increments count, returns false (request allowed).
  class Bucket
    # @return [Integer, nil] the request limit
    attr_reader :limit

    # @return [Integer, nil] the time span for the window
    attr_reader :time_span

    # @return [Integer, nil] the delay between requests
    attr_reader :delay

    CLEANUP_BATCH_SIZE = 128

    # Makes a new bucket
    # @param limit [Integer, nil] How many requests the user may perform in the given time_span, or nil if there should be no limit.
    # @param time_span [Integer, nil] The time span after which the request count is reset, in seconds, or nil if the bucket should never be reset.
    # @param delay [Integer, nil] The delay for which the user has to wait after performing a request, in seconds, or nil if the user shouldn't have to wait.
    # @param clock [#now] Clock object for time sourcing. Defaults to MonotonicClock (Process::CLOCK_MONOTONIC).
    def initialize(limit, time_span, delay, clock: MonotonicClock.new)
      raise ArgumentError, '`limit` and `time_span` have to either both be set or both be nil!' if !limit != !time_span
      raise ArgumentError, '`limit` must be positive!' if limit && limit <= 0
      raise ArgumentError, '`time_span` must be positive!' if time_span && time_span <= 0
      raise ArgumentError, '`delay` must be non-negative!' if delay && delay < 0

      @limit = limit
      @time_span = time_span
      @delay = delay
      @clock = clock

      @bucket = {}
      @mutex = Mutex.new
      @request_count = 0
    end

    # Cleans the bucket, removing all elements that aren't necessary anymore.
    # Thread-safe.
    # @param rate_limit_time [Float, nil] The monotonic time to base the cleaning on, only useful for testing.
    def clean(rate_limit_time = nil)
      @mutex.synchronize do
        rate_limit_time ||= @clock.now
        @bucket.delete_if do |_, entry|
          # Time limit has not run out
          next false if @time_span && rate_limit_time < (entry.set_time + @time_span)

          # Delay has not run out
          next false if @delay && rate_limit_time < (entry.last_time + @delay)

          true
        end
      end
    end

    # Performs a rate limiting request. Thread-safe via Mutex.
    # @param thing [String, Integer, Symbol] The particular thing that should be rate-limited.
    # @param rate_limit_time [Float, nil] The monotonic time to base the rate limiting on, only useful for testing.
    # @param increment [Integer] How much to increment the rate-limit counter. Default is 1.
    # @return [Float, false] the waiting time until the next request, in seconds, or false if the request succeeded.
    def rate_limited?(thing, rate_limit_time = nil, increment: 1)
      # Fast path: no limit and no delay means never rate-limited
      return false if @limit.nil? && @delay.nil?

      key = resolve_key(thing)

      @mutex.synchronize do
        now = rate_limit_time || @clock.now

        # Amortized cleanup: every CLEANUP_BATCH_SIZE * 8 requests, clean a batch
        @request_count += 1
        if @request_count >= CLEANUP_BATCH_SIZE * 8
          @request_count = 0
          clean_batch(now)
        end

        entry = @bucket[key]

        # First case: entry doesn't exist yet
        unless entry
          @bucket[key] = Entry.new(now, now, increment)
          return false
        end

        if @limit && (entry.count + increment) > @limit
          # Second case: Count is over the limit and the time has not run out yet
          if @time_span && now < (entry.set_time + @time_span)
            # Blocked by limit — do NOT update last_time or count
            return (entry.set_time + @time_span) - now
          end

          # Third case: Count is over the limit but the time has run out — reset window
          entry.set_time = now
          entry.count = 0
        end

        if @delay && now < (entry.last_time + @delay)
          # Fourth case: we're being delayed — do NOT consume count
          (entry.last_time + @delay) - now
        else
          # Fifth case: no rate limiting! Increment the count, set the last_time, and return false
          entry.last_time = now
          entry.count += increment
          false
        end
      end
    end

    private

    def resolve_key(thing)
      return thing.resolve_id if thing.respond_to?(:resolve_id) && !thing.is_a?(String)
      return thing if thing.is_a?(Integer) || thing.is_a?(Symbol)

      raise ArgumentError, "Cannot use a #{thing.class} as a rate limiting key!"
    end

    # Incremental cleanup: inspect at most CLEANUP_BATCH_SIZE entries.
    # Called inside the Mutex — must be fast.
    def clean_batch(now)
      count = 0
      @bucket.delete_if do |_, entry|
        count += 1
        break false if count > CLEANUP_BATCH_SIZE

        expired_window = @time_span.nil? || now >= (entry.set_time + @time_span)
        expired_delay = @delay.nil? || now >= (entry.last_time + @delay)
        expired_window && expired_delay
      end
    end
  end

  # Represents a collection of {Bucket}s.
  module RateLimiter
    # Defines a new bucket for this rate limiter.
    # @param key [Symbol] The name for this new bucket.
    # @param attributes [Hash] The attributes to initialize the bucket with.
    # @option attributes [Integer] :limit The limit of requests to perform in the given time span.
    # @option attributes [Integer] :time_span How many seconds until the limit should be reset.
    # @option attributes [Integer] :delay How many seconds the user has to wait after each request.
    # @see Bucket#initialize
    # @return [Bucket] the created bucket.
    def bucket(key, attributes)
      @buckets ||= {}
      @buckets[key] = Bucket.new(attributes[:limit], attributes[:time_span], attributes[:delay])
    end

    # Performs a rate limit request.
    # @param key [Symbol] Which bucket to perform the request for.
    # @param thing [String, Integer, Symbol] What should be rate-limited.
    # @param increment (see Bucket#rate_limited?)
    # @see Bucket#rate_limited?
    # @return [Float, false] How much time to wait or false if the request succeeded.
    def rate_limited?(key, thing, increment: 1)
      # Check whether the bucket actually exists
      return false unless @buckets && @buckets[key]

      @buckets[key].rate_limited?(thing, increment: increment)
    end

    # Cleans all buckets
    # @see Bucket#clean
    def clean
      @buckets&.each_value(&:clean)
    end

    # Adds all the buckets from another RateLimiter onto this one.
    # Copies configuration but creates isolated state (entries, mutex) per bucket.
    # @param limiter [Module] Another {RateLimiter} module
    def include_buckets(limiter)
      other_buckets = limiter.instance_variable_get(:@buckets) || {}
      @buckets ||= {}

      other_buckets.each do |key, other_bucket|
        # Clone configuration but create fresh state (new Entry hash, new Mutex)
        @buckets[key] = Bucket.new(other_bucket.limit, other_bucket.time_span, other_bucket.delay)
      end
    end
  end

  # This class provides a convenient way to do rate-limiting on non-command events.
  # @see RateLimiter
  class SimpleRateLimiter
    include RateLimiter

    # Makes a new rate limiter
    def initialize
      @buckets = {}
    end
  end
end
