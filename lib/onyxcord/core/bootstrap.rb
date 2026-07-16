# frozen_string_literal: true

# Minimal {OnyxCord} module setup with the constants and helpers shared across
# all OnyxCord entry points (light and full). Kept intentionally small so
# `require 'onyxcord/light'` does not pull in gateway/cache/heavy-model files.
#
# The full {OnyxCord} entry point ({lib/onyxcord.rb}) reopens the module to add
# intents, split_message, encode64 and other functionality, but always after
# this file has defined the constants here.
module OnyxCord
  # The Unix timestamp Discord IDs are based on
  DISCORD_EPOCH = 1_420_070_400_000

  # Compares two objects based on IDs — either the objects' IDs are equal, or
  # one object is equal to the other's ID (after calling #resolve_id).
  # @param one_id [Object]
  # @param other [Object]
  # @return [Boolean]
  def self.id_compare?(one_id, other)
    other.respond_to?(:resolve_id) ? (one_id.resolve_id == other.resolve_id) : (one_id == other)
  end
end
