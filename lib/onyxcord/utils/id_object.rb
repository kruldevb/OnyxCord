# frozen_string_literal: true

module OnyxCord
  # Mixin for objects that have IDs.
  module IDObject
    # Minimum snowflake value (positive 64-bit integer).
    MIN_SNOWFLAKE = 0
    # Maximum snowflake value (signed 64-bit).
    MAX_SNOWFLAKE = (1 << 63) - 1
    # Discord epoch start (first second of 2015-01-01 UTC, in milliseconds).
    DISCORD_EPOCH = 1_420_070_400_000

    # @return [Integer] the ID which uniquely identifies this object across Discord.
    attr_reader :id

    # Backwards-compatible alias used by older internal callers.
    alias_method :resolve_id, :id

    # ID based comparison (flexible: compares against id, integer, or string).
    def ==(other)
      OnyxCord.id_compare?(@id, other)
    end

    # Strict ID comparison: only when both sides are IDObjects with normalized IDs.
    def eql?(other)
      return false unless other.is_a?(IDObject)

      normalized_id == other.normalized_id
    end

    # Hash that satisfies the Hash/Set contract.
    # Two equal-by-id objects return the same hash.
    def hash
      normalized_id.hash
    end

    # @return [Integer] the ID, coerced to a positive Integer.
    def normalized_id
      IDObject.coerce_id(@id)
    end

    # Estimates the time this object was generated on based on the beginning of
    # the ID. This is fairly accurate but shouldn't be relied on as Discord
    # might change its algorithm at any time.
    # @return [Time] when this object was created at
    def creation_time
      IDObject.validate_snowflake!(@id)
      ms = (@id >> 22) + DISCORD_EPOCH
      Time.at(ms / 1000.0)
    end

    # Creates an artificial snowflake at the given point in time.
    # @param time [Time] the time the snowflake should represent.
    # @return [Integer] a snowflake with the timestamp data as the given time
    def self.synthesise(time)
      raise ArgumentError, "Expected Time, got #{time.class}" unless time.is_a?(Time)

      ms = (time.to_f * 1000).to_i
      raise ArgumentError, 'time predates Discord epoch (2015-01-01)' if ms < DISCORD_EPOCH

      (ms - DISCORD_EPOCH) << 22
    end

    # Normalize an ID-like value to a positive Integer for comparisons and hashing.
    # @param value [Integer, String, IDObject]
    # @return [Integer]
    def self.coerce_id(value)
      return value.id if value.is_a?(IDObject)

      n = value.to_i
      raise ArgumentError, "ID cannot be negative (#{value.inspect})" if n.negative?

      n
    end

    # Strict snowflake validation (positive 64-bit integer).
    def self.validate_snowflake!(value)
      n = coerce_id(value)
      return n if (MIN_SNOWFLAKE..MAX_SNOWFLAKE).cover?(n)

      raise ArgumentError, "Snowflake #{value.inspect} out of range"
    end

    class << self
      alias_method :synthesize, :synthesise
      alias_method :normalize_id, :coerce_id
    end
  end
end