# frozen_string_literal: true

module OnyxCord
  module Cache
    module Stores
      class NullCacheStore < CacheStore
        def [](_key)
          nil
        end

        def []=(_key, value)
          value
        end

        def delete(_key)
          nil
        end

        def key?(_key)
          false
        end

        alias_method :has_key?, :key?

        def clear
          0
        end

        def delete_if(&block)
          return enum_for(:delete_if) unless block

          self
        end

        def reject!(&block)
          return enum_for(:reject!) unless block

          self
        end

        def each_value(&block)
          return enum_for(:each_value) unless block

          self
        end

        def count
          0
        end

        def capacity
          0
        end

        def enabled?
          false
        end

        def stats
          {}
        end

        def hit_rate
          0.0
        end
      end
    end
  end
end
