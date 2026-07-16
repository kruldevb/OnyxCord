# frozen_string_literal: true

require_relative '../json'

module OnyxCord
  module Internal
    module RateLimiter
      # Discord REST rate limiter keyed by route/major parameter and remapped to
      # X-RateLimit-Bucket whenever Discord returns a concrete bucket id.
      class Rest
        DEFAULT_ENTRY_TTL = 3600
        DEFAULT_PRUNE_INTERVAL = 100

        def initialize(clock: -> { Time.now }, entry_ttl: DEFAULT_ENTRY_TTL, prune_interval: DEFAULT_PRUNE_INTERVAL)
          @route_buckets = {}
          @bucket_mutexes = {}
          @bucket_last_used = {}
          @global_mutex = Mutex.new
          @clock = clock
          @entry_ttl = entry_ttl
          @prune_interval = prune_interval
          @requests_since_prune = 0
        end

        def before_request(route, major_parameter)
          mutex_wait(mutex_for(route, major_parameter))
          mutex_wait(@global_mutex) if @global_mutex.locked?
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
          sync_wait(wait_seconds, mutex_for(route, major_parameter))
        end

        def handle_rate_limit(route, major_parameter, response)
          headers = normalize_headers(response.headers)
          mutex = headers[:x_ratelimit_global] == 'true' || headers[:x_ratelimit_scope] == 'global' ? @global_mutex : mutex_for(route, major_parameter)
          wait_seconds = retry_after(response, headers)

          sync_wait(wait_seconds, mutex) if wait_seconds.positive?
        end

        def stats
          {
            route_buckets: @route_buckets.size,
            bucket_mutexes: @bucket_mutexes.size,
            tracked_keys: @bucket_last_used.size
          }
        end

        def prune!
          return 0 unless @entry_ttl

          cutoff = @clock.call - @entry_ttl
          stale_keys = @bucket_last_used.select { |_, last_used| last_used < cutoff }.keys

          stale_keys.each do |key|
            @bucket_mutexes.delete(key)
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
          @bucket_mutexes[key] ||= Mutex.new
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

        def sync_wait(time, mutex)
          mutex.synchronize { sleep time }
        end

        def mutex_wait(mutex)
          mutex.lock
          mutex.unlock
        end
      end
    end
  end
end
