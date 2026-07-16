# frozen_string_literal: true

module OnyxCord
  # Helpers for Discord message component payloads.
  module MessageComponents
    # Discord message flag for the Components V2 layout system.
    IS_COMPONENTS_V2 = 1 << 15

    # Component types that only exist in the Components V2 message system.
    # See https://docs.discord.com/developers/components/reference#component-object
    V2_COMPONENT_TYPES = [9, 10, 11, 12, 13, 14, 17].freeze

    # Maximum depth we will walk components through, mirroring Discord's
    # 40-component-per-message limit for Components V2.
    MAX_COMPONENT_DEPTH = 8
    MAX_TOTAL_COMPONENTS = 40

    # @return [Set<Integer>] same as V2_COMPONENT_TYPES but as a Set for O(1) lookups.
    V2_TYPE_SET = V2_COMPONENT_TYPES.to_set.freeze

    module_function

    # Convert a component description into the canonical Hash/Array form
    # acceptable by the Discord API.
    #
    # Rules:
    # * nil -> []
    # * Hash -> wrapped into a single-element array
    # * Array -> each element normalized via `to_hash` if possible, else kept as-is
    # * An object exposing `#to_h` is converted via `to_h` (component builders)
    # * An Enumerator or other object exposing only `#to_a` is rejected as ambiguous:
    #   the caller must wrap it explicitly.
    # * Anything else is rejected with ArgumentError.
    #
    # @param components [Object]
    # @return [Array<Hash>]
    def payload(components)
      case components
      when nil
        []
      when Hash
        [components]
      when Array
        components.map { |c| normalize_one(c) }.compact
      else
        if components.respond_to?(:to_h) && !components.is_a?(Enumerator)
          [normalize_one(components.to_h)]
        elsif components.respond_to?(:to_a)
          # Treat Array-likes (e.g. Webhooks::View) as collections.
          payload(components.to_a)
        else
          raise ArgumentError, "Unable to convert #{components.class} into component payload"
        end
      end
    end

    # Determine whether the payload contains Components V2 components.
    # Traverses the structure safely, guarding against cycles
    # and excessive depth.
    def components_v2?(components, visited: Set.new, depth: 0, total: 0)
      payload(components).any? do |component|
        total += 1
        raise ArgumentError, "Too many components (#{total}); Discord limits messages to #{MAX_TOTAL_COMPONENTS}" if total > MAX_TOTAL_COMPONENTS

        component_v2?(component, visited, depth + 1, total: total)
      end
    end

    # Apply the IS_COMPONENTS_V2 flag to the provided message flags.
    def apply_v2_flag(flags, components, force: false)
      return flags unless force || components_v2?(components)

      flag_value(flags) | IS_COMPONENTS_V2
    end

    # Recursively check whether a single component is a Components V2 component.
    def component_v2?(component)
      component_v2?(component, Set.new, 1, total: 0)
    end

    # Internal recursive helper. Tracks `visited` by object_id to detect cycles
    # and enforces depth.
    # @param component [Object]
    # @param visited [Set<Integer>] set of visited object_ids
    # @param depth [Integer] current depth
    # @param total [Integer] total components visited so far
    # @return [Boolean]
    def component_v2?(component, visited, depth, total: 0)
      return false if component.nil?
      raise ArgumentError, "Component nesting too deep (#{MAX_COMPONENT_DEPTH})" if depth > MAX_COMPONENT_DEPTH

      hash = normalize_to_hash(component)
      return false unless hash.is_a?(Hash)

      oid = hash.object_id
      if visited.include?(oid)
        raise ArgumentError, 'Cycle detected in component tree'
      end
      visited.add(oid)

      type = type_of(hash)
      return true if type && V2_TYPE_SET.include?(type)

      children = hash[:components] || hash['components']
      return true if children && components_v2?(children, visited: visited, depth: depth + 1, total: total)

      accessory = hash[:accessory] || hash['accessory']
      component_v2?(accessory, visited, depth + 1, total: total)
    end

    # Coerce a raw integer/symbol/string/enum value into a flag bitset.
    #
    # Validates against known inputs:
    # * Integer used as-is.
    # * Symbol looks up in MessageFlags (if defined) -- falls back to raise.
    # * String is parsed with strict decimal validation.
    # * nil / :undef returns 0 (explicit "no flags set").
    def flag_value(flags)
      if flags.nil? || (flags.is_a?(Symbol) && flags == :undef)
        return 0
      end

      if flags.is_a?(Integer)
        raise ArgumentError, 'flag bitset cannot be negative' if flags.negative?

        return flags
      end

      if flags.is_a?(String)
        stripped = flags.delete_prefix('-')
        raise ArgumentError, "Invalid flag string: #{flags.inspect}" unless /\A\d+\z/.match?(stripped)

        return Integer(stripped, 10).tap { |v| raise ArgumentError if v.negative? }
      end

      if flags.is_a?(Symbol)
        sym = flags
        # Map known flag-like symbols to their bit values.
        bits = MESSAGE_FLAG_BITS[sym]
        raise ArgumentError, "Unknown message flag symbol: #{sym.inspect}" unless bits

        return bits
      end

      if flags.is_a?(Array)
        return flags.reduce(0) do |acc, flag|
          acc | flag_value(flag)
        end
      end

      raise ArgumentError, "Cannot coerce #{flags.class} into a flags integer"
    end

    # Symbol => known flag bit. Subset populated below; absent symbols raise.
    MESSAGE_FLAG_BITS = {
      crossposted:              1 << 0,
      is_crossposted:           1 << 1,
      suppress_embeds:          1 << 2,
      source_message_deleted:   1 << 3,
      urgent:                   1 << 4,
      has_thread:               1 << 5,
      ephemeral:                1 << 6,
      loading:                  1 << 7,
      failed_to_mention_some_roles_in_thread: 1 << 8,
      suppress_notifications:   1 << 12,
      is_voice_message:         1 << 13,
      has_snapshot:             1 << 14,
      is_components_v2:         1 << 15,
    }.freeze

    private_class_method :component_v2?
    module_function :component_v2?

    # Coerce a component (or component-related object) into a Hash if possible.
    # Returns nil if it cannot be represented.
    def normalize_to_hash(component)
      return component if component.is_a?(Hash)

      if component.respond_to?(:to_h) && !component.is_a?(Enumerator)
        component.to_h
      elsif component.respond_to?(:to_hash)
        component.to_hash
      end
    end

    module_function :normalize_to_hash

    # Normalize a single one of the items inside a payload.
    def normalize_one(component)
      if component.is_a?(Hash) || component.is_a?(Array)
        return component
      end

      hash = normalize_to_hash(component)
      raise ArgumentError, "Could not normalize #{component.class} into a component hash" unless hash

      hash
    end
    module_function :normalize_one

    # -------------------------------------------------------------------
    # Helpers for component types
    # -------------------------------------------------------------------

    # Normalize a component-type identifier (Symbol, String, Integer) to Integer.
    # Strings must be strict decimal digits.
    def type_of(component)
      raw = component[:type] || component['type']
      return nil if raw.nil?

      case raw
      when Integer then raw
      when String
        raise ArgumentError, "Invalid component type string: #{raw.inspect}" unless /\A-?\d+\z/.match?(raw)

        Integer(raw)
      else
        raise ArgumentError, "Invalid component type: #{raw.inspect}"
      end
    end
    module_function :type_of
  end
end