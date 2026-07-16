# frozen_string_literal: true

module OnyxCord
  # List of permissions Discord uses
  class Permissions
    # Permission flag registry: canonical_name => bit_position
    REGISTRY = {
      create_instant_invite:      0,
      kick_members:               1,
      ban_members:                2,
      administrator:              3,
      manage_channels:            4,
      manage_guild:               5,
      add_reactions:              6,
      view_audit_log:             7,
      priority_speaker:           8,
      stream:                     9,
      view_channel:               10,
      send_messages:              11,
      send_tts_messages:          12,
      manage_messages:            13,
      embed_links:                14,
      attach_files:               15,
      read_message_history:       16,
      mention_everyone:           17,
      use_external_emojis:        18,
      view_guild_insights:        19,
      connect:                    20,
      speak:                      21,
      mute_members:               22,
      deafen_members:             23,
      move_members:               24,
      use_voice_activity:         25,
      change_nickname:            26,
      manage_nicknames:           27,
      manage_roles:               28,
      manage_webhooks:            29,
      manage_guild_expressions:   30,
      use_application_commands:   31,
      request_to_speak:           32,
      manage_events:              33,
      manage_threads:             34,
      create_public_threads:      35,
      create_private_threads:     36,
      use_external_stickers:      37,
      send_messages_in_threads:   38,
      use_embedded_activities:    39,
      moderate_members:           40,
      view_monetization_analytics: 41,
      use_soundboard:             42,
      create_guild_expressions:   43,
      create_events:              44,
      use_external_sounds:        45,
      send_voice_messages:        46,
      set_voice_channel_status:   48,
      send_polls:                 49,
      use_external_apps:          50,
      pin_messages:               51,
      bypass_slowmode:            52,
    }.freeze

    # Canonical name aliases for deprecated/legacy names.
    # The canonical name is the key, aliases are the values.
    CANONICAL_ALIASES = {
      manage_guild:              %i[manage_server],
      view_channel:              %i[read_messages],
      use_external_emojis:       %i[use_external_emoji],
      manage_guild_expressions:  %i[manage_emojis manage_stickers],
      use_application_commands:  %i[use_slash_commands],
      create_public_threads:     %i[use_public_threads],
      create_private_threads:    %i[use_private_threads],
      create_guild_expressions:  %i[create_server_expressions],
      create_events:             %i[create_scheduled_events],
      view_guild_insights:       %i[view_server_insights],
    }.freeze

    # Reverse lookup: any recognized name (canonical or alias) => canonical_name
    NAME_MAP = REGISTRY.each_with_object({}) do |(canonical, position), map|
      map[canonical] = canonical
      (CANONICAL_ALIASES[canonical] || []).each { |alias_name| map[alias_name] = canonical }
    end.freeze

    # Reverse lookup: canonical_name => bit_mask
    BIT_MAP = REGISTRY.each_with_object({}) do |(canonical, position), map|
      map[canonical] = 1 << position
    end.freeze

    # @deprecated Use {REGISTRY} or {BIT_MAP} instead.
    # Maintained for backward-compatibility: position => symbol.
    FLAGS = REGISTRY.invert.freeze

    # Static map of implicit permissions that are unusable when certain
    # prerequisite permissions are denied.
    IMPLICIT_DEPENDENCIES = {
      view_channel: %i[
        send_messages send_tts_messages manage_messages embed_links attach_files
        read_message_history mention_everyone use_external_emojis add_reactions
        use_external_stickers use_embedded_activities use_application_commands connect
        speak priority_speaker stream use_voice_activity mute_members deafen_members
        move_members request_to_speak set_voice_channel_status create_instant_invite
        manage_webhooks manage_guild_expressions create_guild_expressions manage_events
        create_events manage_threads create_public_threads create_private_threads
        send_messages_in_threads send_polls use_external_apps
      ].freeze,
      send_messages: %i[
        send_tts_messages embed_links attach_files mention_everyone send_polls
      ].freeze,
      connect: %i[
        speak priority_speaker stream use_voice_activity mute_members deafen_members
        move_members request_to_speak set_voice_channel_status
      ].freeze,
    }.freeze

    IMPLICIT_DEPENDENCIES.each_value(&:freeze)

    define_method(:can_administrate=) { |value| send(:can_administrator=, value) }

    # @!attribute [r] bits
    #   @return [Integer] raw bitset
    attr_reader :bits

    # @!visibility private
    attr_reader :writer

    # Create a new Permissions object.
    # @param bits [Integer, String, Array<Symbol>] permission bits or list of symbols
    # @param writer [Object, nil] an object that responds to #write for persisting changes
    def initialize(bits = 0, writer = nil)
      @writer = writer

      @bits = case bits
              when nil
                0
              when Integer
                raise ArgumentError, 'Permission bits cannot be negative' if bits.negative?

                bits
              when String
                Integer(bits, exception: true)
              when Array
                bits = bits.map do |sym|
                  resolved = NAME_MAP[sym.to_sym] or raise ArgumentError, "Unknown permission: #{sym.inspect}"
                  resolved
                end
                self.class.bits(bits)
              else
                raise ArgumentError, "Expected Integer, String, or Array, got #{bits.class}"
              end

      init_vars
    end

    # Build bits from an array of permission names.
    # @param list [Array<Symbol>]
    # @return [Integer]
    def self.bits(list)
      value = 0
      list.each do |name|
        canonical = NAME_MAP[name] or raise ArgumentError, "Unknown permission: #{name.inspect}"
        value |= BIT_MAP[canonical]
      end
      value
    end

    # Set raw bitset and rebuild cached predicates.
    def bits=(bits)
      raise ArgumentError, 'Permission bits cannot be negative' if bits.negative?

      @bits = Integer(bits)
      init_vars
    end

    # Mutate the object via a batch of boolean permission changes without persisting.
    # @param changes [Hash{Symbol => Boolean}]
    # @return [self]
    def assign(changes)
      changes.each do |name, value|
        canonical = NAME_MAP[name] or raise ArgumentError, "Unknown permission: #{name.inspect}"
        mask = BIT_MAP[canonical]
        if value
          @bits |= mask
        else
          @bits &= ~mask
        end
      end
      init_vars
      self
    end

    # Mutate and persist via writer.
    # @param changes [Hash{Symbol => Boolean}]
    # @return [self]
    def assign!(changes)
      assign(changes)
      @writer&.write(@bits)
      self
    end

    # Persist current bits without changing state.
    # @return [void]
    def write_bits
      @writer&.write(@bits)
    end

    # Return the permission flag names currently set.
    # @return [Array<Symbol>]
    def defined_permissions
      BIT_MAP.filter_map { |canonical, mask| canonical if (@bits & mask) != 0 }
    end

    # Check whether a given permission is set.
    # @param action [Symbol] canonical or alias permission name
    # @return [Boolean]
    def permission?(action)
      canonical = canonical_name(action)
      raise ArgumentError, "Unknown permission: #{action.inspect}" unless canonical

      (@bits & BIT_MAP[canonical]) != 0
    end

    # Check with an allowlist: only valid permission names pass.
    def defined_permission?(action)
      permission?(action)
    end

    # Comparison based on bits
    def ==(other)
      return false unless other.is_a?(OnyxCord::Permissions)

      bits == other.bits
    end

    # Initialize instance variable predicates from bitset.
    def init_vars
      BIT_MAP.each do |canonical, mask|
        instance_variable_set("@#{canonical}", (@bits & mask) != 0)
      end
    end

    private

    def canonical_name(action)
      NAME_MAP[action.to_sym]
    end

    public

    # -------------------------------------------------------------------
    # Dynamic getters, setters, and predicate methods
    # -------------------------------------------------------------------
    REGISTRY.each do |canonical, position|
      attr_reader canonical

      # Setter with persistence
      define_method("can_#{canonical}=") do |value|
        mask = BIT_MAP[canonical]
        if value
          @bits |= mask
        else
          @bits &= ~mask
        end
        instance_variable_set("@#{canonical}", value)
        write_bits
      end

      # Predicate
      define_method("can_#{canonical}?") do
        (@bits & BIT_MAP[canonical]) != 0
      end
    end

    # Dynamically generate aliases for deprecated/legacy names.
    CANONICAL_ALIASES.each do |canonical, aliases|
      aliases.each do |alias_name|
        alias_method "can_#{alias_name}=",  "can_#{canonical}="
        alias_method "can_#{alias_name}?",  "can_#{canonical}?"
        alias_method alias_name,            canonical
      end
    end

    alias_method :administrate, :administrator
  end

  # -------------------------------------------------------------------
  # PermissionCalculator — mixin for members / profiles
  # -------------------------------------------------------------------
  module PermissionCalculator
    # @param time [Time, nil] custom "now" for testing timeouts (default: Time.now)
    # @return [Boolean]
    def permission?(action, channel = nil, time: nil)
      now = time || Time.now
      defined = lambda do |act, ch = channel|
        defined_permission?(act, ch, time: now)
      end

      # Owner irrevocably has all permissions
      return true if owner?

      # Timeout strips everything except view_channel and read_message_history
      # unless owner or administrator.
      if respond_to?(:communication_disabled?) && communication_disabled? &&
         !owner? && !defined.call(:administrator)
        canonical = OnyxCord::Permissions::NAME_MAP[action.to_sym]
        return false unless canonical

        return %i[view_channel read_message_history].include?(canonical)
      end

      # Administrator bypass
      return true if defined.call(:administrator)

      raw = defined.call(action)
      return false unless raw

      return apply_implicit_denies(action, channel) unless time
      apply_implicit_denies(action, channel, time: time)
    end

    # Check whether the permission bit is actually set, considering
    # role and channel overwrites.
    # @param action [Symbol]
    # @param channel [Channel, nil]
    # @param time [Time, nil] custom "now" for testing timeouts
    # @return [Boolean]
    def defined_permission?(action, channel = nil, time: Time.now)
      canonical = OnyxCord::Permissions::NAME_MAP[action.to_sym]
      raise ArgumentError, "Unknown permission: #{action.inspect}" unless canonical

      # interaction-provided permissions fallback (no server context)
      return @permissions.permission?(action) if @permissions && channel.nil?

      # Compute effective permission via Discord's official overwrite order
      raw = defined_role_permission?(canonical, channel)
      member_override = permission_overwrite(canonical, channel, resolve_id)
      return raw unless member_override

      member_override == :allow
    end

    # Predicate shortcuts
    OnyxCord::Permissions::REGISTRY.each_key do |canonical|
      define_method("can_#{canonical}?") do |channel = nil|
        permission?(canonical, channel)
      end
    end

    # Deprecated alias predicates for legacy names
    OnyxCord::Permissions::CANONICAL_ALIASES.each do |canonical, aliases|
      aliases.each do |alias_name|
        alias_method "can_#{alias_name}?", "can_#{canonical}?"
      end
    end

    alias_method :can_administrate?, :can_administrator?

    private

    # Apply Discord's implicit permission dependencies.
    def apply_implicit_denies(action, channel = nil, time: Time.now)
      canonical = OnyxCord::Permissions::NAME_MAP[action.to_sym]
      return true unless canonical

      OnyxCord::Permissions::IMPLICIT_DEPENDENCIES.each do |prerequisite, dependents|
        next unless dependents.include?(canonical)

        return false unless defined_permission?(prerequisite, channel, time: time)
      end
      true
    end

    # Permission overwrite algorithm following Discord's official order:
    #   1. Base permissions: OR @everyone base + all role bases
    #   2. Apply @everyone overwrites (allow/deny)
    #   3. Apply all role overwrites:
    #      a. Combine all role denies (OR)
    #      b. Combine all role allows (OR)
    #      c. Apply denies first, then allows
    #   4. Apply member overwrite
    #
    # Role position does NOT decide overwrite conflicts per Discord docs.
    def defined_role_permission?(action, channel)
      everyone = @server.everyone_role

      # Step 1: base permissions
      base_bits = everyone.permissions.bits
      roles.each { |role| base_bits |= role.permissions.bits }

      # Convert to boolean for specific action
      action_mask = OnyxCord::Permissions::BIT_MAP[action]
      return false unless action_mask

      is_set = (base_bits & action_mask) != 0

      # Step 2: @everyone overwrite
      if channel
        everyone_override = permission_overwrite(action, channel, everyone.id)
        case everyone_override
        when :allow then is_set = true
        when :deny  then is_set = false
        end
      end

      # Step 3: combine all role overwrites
      if channel
        role_denies = 0
        role_allows = 0
        roles.each do |role|
          override = permission_overwrite(action, channel, role.id)
          case override
          when :allow then role_allows |= action_mask
          when :deny  then role_denies |= action_mask
          end
        end

        is_set = false if (role_denies & action_mask) != 0
        is_set = true  if (role_allows & action_mask) != 0
      end

      is_set
    end

    def permission_overwrite(action, channel, id)
      return nil unless channel && channel.permission_overwrites[id]

      ow = channel.permission_overwrites[id]
      mask = OnyxCord::Permissions::BIT_MAP[action]
      return nil unless mask

      if (ow.allow.bits & mask) != 0
        :allow
      elsif (ow.deny.bits & mask) != 0
        :deny
      end
    end
  end
end