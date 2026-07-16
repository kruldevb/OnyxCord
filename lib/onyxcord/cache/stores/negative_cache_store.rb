# frozen_string_literal: true

module OnyxCord
  module Cache
    module Stores
      class NegativeCacheStore < TtlCacheStore
        def add(key, ttl: nil)
          actual_ttl = ttl || @ttl
          @mutex.synchronize do
            @store[key] = [Time.now + actual_ttl, true]
          end
        end

        def [](key)
          result = super
          result ? :negative_cached : nil
        end

        def remove(key)
          delete(key)
        end
      end
    end
  end
end