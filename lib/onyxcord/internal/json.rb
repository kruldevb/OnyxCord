# frozen_string_literal: true

require 'oj'

# Configure Oj for direct use (not via stdlib JSON compatibility).
# This is loaded early by the main onyxcord.rb entry point.
module OnyxCord
  module Internal
    module JSON
      Oj.default_options = { mode: :compat, symbol_keys: false, allow_nan: false }

      module_function

      # Fast JSON decode using Oj directly.
      # @param data [String] The JSON string to decode.
      # @return [Hash, Array, String, Numeric, nil]
      def decode(data, **options)
        Oj.load(data, **options)
      end

      # Fast JSON encode using Oj directly.
      # @param data [Object] The object to encode as JSON.
      # @return [String]
      def encode(data, **options)
        Oj.dump(data, **options)
      end

      # Alias parse to decode for standard library compatibility
      def parse(data, **options)
        Oj.load(data, **options)
      end

      # Alias generate to encode for standard library compatibility
      def generate(data, **options)
        Oj.dump(data, **options)
      end

      # Alias load to decode for Oj/JSON compatibility
      def load(data, **options)
        Oj.load(data, **options)
      end

      # Alias dump to encode for Oj/JSON compatibility
      def dump(data, **options)
        Oj.dump(data, **options)
      end
    end
  end
end
