# frozen_string_literal: true

require 'lru_redux'

module OnyxCord
  module Cache
    module Stores
      class LruReduxWithStats < LruRedux::ThreadSafeCache
        attr_accessor :stats_tracker, :max_size

        def []=(key, value)
          existing_key = key?(key)
          old_count = count

          super

          new_count = count
          evict_happened = !existing_key && new_count == old_count && old_count >= max_size
          @stats_tracker.on_insert(existing_key, evict_happened)
        end

        def delete(key)
          result = super
          @stats_tracker.on_delete if result
          result
        end

        def clear
          result = super
          @stats_tracker.on_clear
          result
        end
      end

      class LruCacheStore < CacheStore
        def initialize(max_size, enabled: true)
          super()
          @max_size = max_size
          @store = enabled ? LruReduxWithStats.new(max_size) : nil
          @store&.max_size = max_size
          @store&.stats_tracker = self
          @enabled = enabled
          @capacity = max_size
          @sampled_memory = 0
          @sample_count = 0
          @total_memory = 0
        end

        def [](key)
          return nil unless @store

          result = @store[key]
          if result
            @hits += 1
          else
            @misses += 1
          end
          result
        end

        def []=(key, value)
          return unless @store

          sample_memory(value)
          @store[key] = value
        end

        def delete(key)
          return nil unless @store

          @store.delete(key)
        end

        def key?(key)
          return false unless @store

          @store.key?(key)
        end

        alias_method :has_key?, :key?

        def clear
          return 0 unless @store

          @store.clear
        end

        def each_value(&block)
          return enum_for(:each_value) unless @store
          return enum_for(:each_value) unless block

          @store.each { |_, value| yield value }
        end

        def delete_if(&block)
          return enum_for(:delete_if) unless block
          return self unless @store

          keys_to_delete = []
          @store.each do |key, value|
            keys_to_delete << key if yield(value)
          end
          keys_to_delete.each { |key| @store.delete(key) }
          self
        end

        def reject!(&block)
          return enum_for(:reject!) unless block
          return self unless @store

          keys_to_delete = []
          @store.each do |key, value|
            keys_to_delete << key if yield(value)
          end
          keys_to_delete.each { |key| @store.delete(key) }
          self
        end

        def count
          @store ? @store.count : 0
        end

        attr_reader :capacity

        def enabled?
          @enabled
        end

        def stats
          {
            size: count,
            capacity: capacity,
            hits: hits,
            misses: misses,
            insertions: insertions,
            evictions: evictions,
            hit_rate: hit_rate,
            estimated_bytes: estimated_memory
          }
        end

        def estimated_memory
          return 0 if @sample_count < 2

          per_entry = @total_memory.to_f / @sample_count
          (per_entry * count).to_i
        end

        def on_insert(was_existing, was_evicted)
          if was_evicted
            @evictions += 1
          else
            @insertions += 1 unless was_existing
          end
        end

        def on_delete
          @insertions = [@insertions - 1, 0].max
        end

        def on_clear
          @insertions = 0
          @evictions = 0
        end

        private

        def sample_memory(value)
          @sample_count += 1
          return unless @sample_count % 100 == 0

          mem = ObjectSpace.memsize_of(value)
          @total_memory += mem
        end
      end
    end
  end
end
