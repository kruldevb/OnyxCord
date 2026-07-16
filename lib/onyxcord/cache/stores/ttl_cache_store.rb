# frozen_string_literal: true

module OnyxCord
  module Cache
    module Stores
      class TtlCacheStore < CacheStore
        attr_reader :ttl, :capacity

        def initialize(ttl, enabled: true, jitter_range: nil)
          super()
          @store = enabled ? {} : nil
          @ttl = ttl
          @jitter_range = jitter_range
          @enabled = enabled
          @capacity = Float::INFINITY
          @mutex = Mutex.new
        end

        def [](key)
          return nil unless @store

          @mutex.synchronize do
            entry = @store[key]
            return nil unless entry

            expires_at, value = entry
            if Time.now > expires_at
              @store.delete(key)
              @misses += 1
              return nil
            end

            @hits += 1
            value
          end
        end

        def []=(key, value)
          return unless @store

          @mutex.synchronize do
            actual_ttl = if @jitter_range
                           @ttl + rand(@jitter_range)
                         else
                           @ttl
                         end

            @store[key] = [Time.now + actual_ttl, value]
            @insertions += 1
          end
        end

        def delete(key)
          return nil unless @store

          @mutex.synchronize { @store.delete(key) }
        end

        def key?(key)
          return false unless @store

          @mutex.synchronize do
            entry = @store[key]
            return false unless entry

            expires_at, = entry
            if Time.now > expires_at
              @store.delete(key)
              return false
            end
            true
          end
        end

        alias_method :has_key?, :key?

        def clear
          return 0 unless @store

          @mutex.synchronize do
            count = @store.size
            @store.clear
            count
          end
        end

        def each_value(&block)
          return enum_for(:each_value) unless @store
          return enum_for(:each_value) unless block

          @mutex.synchronize do
            now = Time.now
            @store.delete_if do |(expires_at, _), _|
              expires_at <= now
            end

            @store.each_value do |(_, value)|
              yield(value)
            end
          end
        end

        def count
          return 0 unless @store

          @mutex.synchronize do
            prune
            @store.size
          end
        end

        def enabled?
          @enabled
        end

        def stats
          @mutex.synchronize do
            prune
            {
              size: @store ? @store.size : 0,
              capacity: capacity,
              hits: hits,
              misses: misses,
              insertions: insertions,
              evictions: 0,
              hit_rate: hit_rate,
              estimated_bytes: estimated_memory
            }
          end
        end

        private

        def prune
          return unless @store

          now = Time.now
          @store.delete_if do |(expires_at, _), _|
            expires_at <= now
          end
        end
      end
    end
  end
end
