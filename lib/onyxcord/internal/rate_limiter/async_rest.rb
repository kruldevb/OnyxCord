# frozen_string_literal: true

require_relative '../async_runtime'

module OnyxCord
  module Internal
    module RateLimiter
      class AsyncRest
        DEFAULT_ENTRY_TTL = 3600
        DEFAULT_PRUNE_INTERVAL = 100

        def initialize(clock: -> { Time.now }, entry_ttl: DEFAULT_ENTRY_TTL, prune_interval: DEFAULT_PRUNE_INTERVAL)
          @route_buckets = {}
          @bucket_locks = {}
          @bucket_last_used = {}
          @global_lock = Mutex.new
          @clock = clock
          @entry_ttl = entry_ttl
          @prune_interval = prune_interval
          @requests_since_prune = 0
        end

        def before_request(route, major_parameter)
          wait_for(@global_lock)
          wait_for(mutex_for(route, major_parameter))
        end

        def record_response(route, major_parameter, headers)
          headers = normalize_headers(headers)
          bucket = headers[:x_ratelimit_bucket]
          key = route_key(route, major_parameter)
          touch(key)

          if bucket
            bucket = bucket_key(bucket, major_parameter)
            @route_buckets[key] = bucket
            touch(bucket)
          end

          # Only wait if remaining is 0 AND reset_after is > 2 seconds
          # This avoids premature blocking while still respecting hard limits
          return unless headers[:x_ratelimit_remaining] == '0'

          wait_seconds = headers[:x_ratelimit_reset_after].to_f
          return unless wait_seconds > 2.0

          OnyxCord::LOGGER.warn("Rate limit remaining=0, waiting #{wait_seconds.round(2)}s")
          async_wait(wait_seconds, mutex_for(route, major_parameter))
        end

        def handle_rate_limit(route, major_parameter, response)
          headers = normalize_headers(response.headers)
          wait_seconds = retry_after(response, headers)

          return unless wait_seconds.positive?

          if headers[:x_ratelimit_global] == 'true' || headers[:x_ratelimit_scope] == 'global'
            global_wait(wait_seconds)
          else
            async_wait(wait_seconds, mutex_for(route, major_parameter))
          end
        end

        def stats
          {
            route_buckets: @route_buckets.size,
            bucket_locks: @bucket_locks.size,
            tracked_keys: @bucket_last_used.size
          }
        end

        def prune!
          return 0 unless @entry_ttl

          cutoff = @clock.call - @entry_ttl
          stale_keys = @bucket_last_used.select { |_, last_used| last_used < cutoff }.keys

          stale_keys.each do |key|
            @bucket_locks.delete(key)
            @bucket_last_used.delete(key)
            @route_buckets.delete(key)
            @route_buckets.delete_if { |_, bucket_key| bucket_key == key }
          end

          @requests_since_prune = 0
          stale_keys.length
        end

        private

        def mutex_for(route, major_parameter)
          key = resolved_key(route, major_parameter)
          touch(key)
          @bucket_locks[key] ||= Mutex.new
        end

        def resolved_key(route, major_parameter)
          @route_buckets[route_key(route, major_parameter)] || route_key(route, major_parameter)
        end

        def route_key(route, major_parameter)
          [route, major_parameter].freeze
        end

        def bucket_key(bucket, major_parameter)
          [:bucket, bucket, major_parameter].freeze
        end

        def retry_after(response, headers)
          body = response.respond_to?(:body) ? response.body : response.to_s
          if body && !body.empty?
            data = JSON.parse(body)
            return data['retry_after'].to_f if data['retry_after']
          end

          (headers[:retry_after] || 0).to_f
        rescue JSON::ParserError
          (headers[:retry_after] || 0).to_f
        end

        def normalize_headers(headers)
          headers.each_with_object({}) do |(key, value), memo|
            memo[key.to_s.tr('-', '_').downcase.to_sym] = value.to_s
          end
        end

        def touch(key)
          @bucket_last_used[key] = @clock.call
          prune_if_needed
        end

        def prune_if_needed
          return unless @prune_interval

          @requests_since_prune += 1
          prune! if @requests_since_prune >= @prune_interval
        end

        def wait_for(mutex)
          mutex.lock
          mutex.unlock
        end

        def async_wait(time, mutex)
          mutex.synchronize { AsyncRuntime.sleep(time) }
        end

        def global_wait(time)
          async_wait(time, @global_lock)
        end
      end
    end
  end
end
