# frozen_string_literal: true

require 'json'

module OnyxCord
  module RateLimiter
    # Discord REST rate limiter keyed by route/major parameter and remapped to
    # X-RateLimit-Bucket whenever Discord returns a concrete bucket id.
    class Rest
      def initialize
        @route_buckets = {}
        @bucket_mutexes = {}
        @global_mutex = Mutex.new
      end

      def before_request(route, major_parameter)
        mutex_wait(mutex_for(route, major_parameter))
        mutex_wait(@global_mutex) if @global_mutex.locked?
      end

      def record_response(route, major_parameter, headers)
        headers = normalize_headers(headers)
        bucket = headers[:x_ratelimit_bucket]

        @route_buckets[route_key(route, major_parameter)] = bucket_key(bucket, major_parameter) if bucket

        return unless headers[:x_ratelimit_remaining] == '0'

        wait_seconds = headers[:x_ratelimit_reset_after].to_f
        return unless wait_seconds.positive?

        sync_wait(wait_seconds, mutex_for(route, major_parameter))
      end

      def handle_rate_limit(route, major_parameter, response)
        headers = normalize_headers(response.headers)
        mutex = headers[:x_ratelimit_global] == 'true' || headers[:x_ratelimit_scope] == 'global' ? @global_mutex : mutex_for(route, major_parameter)
        wait_seconds = retry_after(response, headers)

        sync_wait(wait_seconds, mutex) if wait_seconds.positive?
      end

      private

      def mutex_for(route, major_parameter)
        @bucket_mutexes[resolved_key(route, major_parameter)] ||= Mutex.new
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
