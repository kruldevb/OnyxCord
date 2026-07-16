# frozen_string_literal: true

module OnyxCord
  module Cache
    module Stores
      class CacheStore
        attr_reader :hits, :misses, :insertions, :evictions

        def initialize
          reset_stats
        end

        def stats
          {}
        end

        def reset_stats
          @hits = 0
          @misses = 0
          @insertions = 0
          @evictions = 0
        end

        def [](key)
          raise NotImplementedError, "#{self.class} does not implement #[]"
        end

        def []=(key, value)
          raise NotImplementedError, "#{self.class} does not implement #[]="
        end

        def delete(key)
          raise NotImplementedError, "#{self.class} does not implement #delete"
        end

        def clear
          raise NotImplementedError, "#{self.class} does not implement #clear"
        end

        def each_value(&block)
          raise NotImplementedError, "#{self.class} does not implement #each_value"
        end

        def count
          raise NotImplementedError, "#{self.class} does not implement #count"
        end

        def capacity
          raise NotImplementedError, "#{self.class} does not implement #capacity"
        end

        def enabled?
          raise NotImplementedError, "#{self.class} does not implement #enabled?"
        end

        def hit_rate
          total = @hits + @misses
          total.zero? ? 0.0 : (@hits.to_f / total)
        end

        def estimated_memory
          0
        end
      end
    end
  end
end
