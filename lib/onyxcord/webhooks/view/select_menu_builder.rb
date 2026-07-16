# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class SelectMenuBuilder
    # Select types that accept an +options+ array.
    OPTION_SELECTS = %i[string_select].freeze

    # Select types that accept +default_values+.
    DEFAULT_VALUE_SELECTS = %i[user_select role_select mentionable_select channel_select].freeze

    # Maximum number of options in a string select.
    MAX_OPTIONS = 25

    # Maximum character length for an option label.
    MAX_LABEL_LENGTH = 100

    # Maximum character length for an option value.
    MAX_VALUE_LENGTH = 100

    # Maximum character length for an option description.
    MAX_DESCRIPTION_LENGTH = 100

    # @!visibility private
    def initialize(custom_id, options = [], placeholder = nil, min_values = nil, max_values = nil, disabled = nil, select_type: :string_select, id: nil, required: nil, default_values: nil)
      @id = id
      @custom_id = custom_id
      @options = options
      @placeholder = placeholder
      @min_values = min_values
      @max_values = max_values
      @disabled = disabled
      @select_type = select_type
      @required = required
      @default_values = process_defaults(default_values)
    end

    # Add an option to this select menu.
    #
    # @param label [String] The title of this option.
    # @param value [String] The value that this option represents.
    # @param description [String, nil] An optional description.
    # @param emoji [#to_h, String, Integer] An emoji to attach.
    # @param default [true, false, nil] Whether this is the default selected option.
    # @raise [ArgumentError] if option limits are exceeded.
    def option(label:, value:, description: nil, emoji: nil, default: nil)
      validate_string_select_option!(label, value, description)
      emoji = normalize_emoji(emoji)

      @options << { label: label, value: value, description: description, emoji: emoji, default: default }
    end

    # @!visibility private
    def to_h
      validate! if OPTION_SELECTS.include?(@select_type)

      data = {
        type: COMPONENT_TYPES[@select_type],
        id: @id,
        custom_id: @custom_id,
        placeholder: @placeholder,
        min_values: @min_values,
        max_values: @max_values,
        disabled: @disabled,
        required: @required
      }

      # WEBHOOK-0302: +options+ only belongs to string_select.
      data[:options] = @options if OPTION_SELECTS.include?(@select_type)

      # WEBHOOK-0302: +default_values+ only on user/role/mentionable/channel selects.
      data[:default_values] = @default_values if @default_values && DEFAULT_VALUE_SELECTS.include?(@select_type)

      data.compact
    end

    private

    # Validate string select option limits.
    def validate_string_select_option!(label, value, description)
      if label.nil? || label.to_s.empty?
        raise ArgumentError, 'Option label must not be nil or empty'
      end

      if value.nil? || value.to_s.empty?
        raise ArgumentError, 'Option value must not be nil or empty'
      end

      label_str = label.to_s
      value_str = value.to_s

      if label_str.length > MAX_LABEL_LENGTH
        raise ArgumentError, "Option label too long: #{label_str.length} chars (max #{MAX_LABEL_LENGTH})"
      end

      if value_str.length > MAX_VALUE_LENGTH
        raise ArgumentError, "Option value too long: #{value_str.length} chars (max #{MAX_VALUE_LENGTH})"
      end

      if description && description.to_s.length > MAX_DESCRIPTION_LENGTH
        raise ArgumentError, "Option description too long: #{description.to_s.length} chars (max #{MAX_DESCRIPTION_LENGTH})"
      end
    end

    # Validate the full string select before serialization.
    def validate!
      if @options.length > MAX_OPTIONS
        raise ArgumentError, "Too many options: #{@options.length} (max #{MAX_OPTIONS})"
      end

      # Check for duplicate values
      values = @options.map { |o| o[:value] }.compact
      if values.uniq.length != values.length
        duplicates = values.select { |v| values.count(v) > 1 }.uniq
        raise ArgumentError, "Duplicate option values: #{duplicates.inspect}"
      end
    end

    # Normalize an emoji value to a Hash.
    def normalize_emoji(emoji)
      case emoji
      when Integer
        { id: emoji.to_s }
      when String
        # Fully numeric string = custom emoji snowflake; otherwise unicode name.
        emoji.match?(/\A\d+\z/) ? { id: emoji } : { name: emoji }
      when Hash
        emoji
      else
        emoji&.to_h
      end
    end

    # Normalize default values by select type.
    def process_defaults(default_values)
      return nil if default_values.nil?

      case @select_type
      when :mentionable_select
        default_values.map { |dv| normalize_mentionable_default(dv) }
      when :user_select
        default_values.map { |dv| normalize_entity_default(dv, 'user') }
      when :role_select
        default_values.map { |dv| normalize_entity_default(dv, 'role') }
      when :channel_select
        default_values.map { |dv| normalize_entity_default(dv, 'channel') }
      else
        # string_select and others don't have default_values
        nil
      end
    end

    def normalize_mentionable_default(value)
      case value
      when OnyxCord::Recipient, OnyxCord::User, OnyxCord::Member
        { id: resolve_to_id(value), type: 'user' }
      when OnyxCord::Role
        { id: resolve_to_id(value), type: 'role' }
      when Hash
        value
      when Integer, String
        raise ArgumentError, "Cannot determine type for mentionable default #{value.inspect}; pass a Hash with type: 'user' or type: 'role'"
      else
        raise TypeError, "Unsupported mentionable default type: #{value.class}"
      end
    end

    def normalize_entity_default(value, type)
      case value
      when Hash
        value
      when Integer
        { id: value.to_s, type: type }
      when String
        { id: value, type: type }
      else
        { id: resolve_to_id(value), type: type }
      end
    end

    def resolve_to_id(obj)
      return obj.to_s if obj.is_a?(Integer)
      return obj if obj.is_a?(String) && obj.match?(/\A\d+\z/)
      return obj.id.to_s if obj.respond_to?(:id)

      raise TypeError, "Cannot extract ID from #{obj.class}"
    end
  end
end
