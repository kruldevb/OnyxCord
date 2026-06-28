# frozen_string_literal: true

require 'oj'

# Configure Oj in compat mode so that all stdlib JSON.parse / .to_json calls
# are transparently accelerated. This is loaded early by the main onyxcord.rb
# entry point so every module benefits automatically.
module OnyxCord
  # Fast Oj-backed JSON wrapper providing compatibility with stdlib JSON methods.
  module JSON
    Oj.default_options = { mode: :compat, symbol_keys: false }

    module_function

    # Fast JSON decode using Oj via stdlib JSON compatibility.
    # @param data [String] The JSON string to decode.
    # @return [Hash, Array, String, Numeric, nil]
    def decode(data, *args)
      ::JSON.parse(data, *args)
    end

    # Fast JSON encode using Oj via stdlib JSON compatibility.
    # @param data [Object] The object to encode as JSON.
    # @return [String]
    def encode(data, *args)
      ::JSON.generate(data, *args)
    end

    # Alias parse to decode for standard library compatibility
    def parse(data, *args)
      ::JSON.parse(data, *args)
    end

    # Alias generate to encode for standard library compatibility
    def generate(data, *args)
      ::JSON.generate(data, *args)
    end

    # Alias load to decode for Oj/JSON compatibility
    def load(data, *args)
      ::JSON.parse(data, *args)
    end

    # Alias dump to encode for Oj/JSON compatibility
    def dump(data, *args)
      ::JSON.generate(data, *args)
    end
  end
end
