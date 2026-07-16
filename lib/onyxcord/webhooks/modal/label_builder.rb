# frozen_string_literal: true

class OnyxCord::Webhooks::Modal
  class LabelBuilder
    MAX_LABEL_LENGTH = 45
    MAX_DESCRIPTION_LENGTH = 120
    MAX_TEXT_INPUT_LENGTH = 4000
    MAX_CUSTOM_ID_LENGTH = 100
    VALID_TEXT_INPUT_STYLES = [1, 2].freeze

    # A mapping of text input styles to symbol names.
    TEXT_INPUT_STYLES = {
      short: 1,
      paragraph: 2
    }.freeze

    # Create a label component.
    #
    # @param label [String, nil] The label text.  Will be required in 4.0.
    # @param id [Integer, nil] The unique 32-bit ID of the label component.
    # @param description [String, nil] The description of the label component.
    # @yieldparam builder [LabelBuilder] Yields the initialized label.
    def initialize(label: nil, id: nil, description: nil)
      @id = id
      @label = label
      @description = description
      @component = nil

      yield self if block_given?
    end

    # Add a text input to the label component.
    #
    # @param style [Symbol, Integer] The text input style.  +:short+ or
    #   +:paragraph+.
    # @param custom_id [String] Custom ID.  Limit of 100 characters.
    # @param id [Integer] The integer ID for this component.
    # @param min_length [Integer, nil] Minimum input length (0..4000).
    # @param max_length [Integer, nil] Maximum input length (1..4000).
    # @param required [true, false, nil] Whether this is required.
    # @param value [String, nil] A pre-filled value (max 4000 characters).
    # @param placeholder [String, nil] Placeholder text (max 100 characters).
    def text_input(style:, custom_id:, id: nil, min_length: nil, max_length: nil, required: nil, value: nil, placeholder: nil)
      validate_text_input!(style, custom_id, min_length, max_length, value, placeholder)

      @component = {
        id: id,
        style: TEXT_INPUT_STYLES[style] || style,
        custom_id: custom_id,
        type: COMPONENT_TYPES[:text_input],
        min_length: min_length,
        max_length: max_length,
        required: required,
        value: value,
        placeholder: placeholder
      }.compact
    end

    # Add a string select menu to the label component.
    #
    # @param custom_id [String] Custom ID.
    # @param id [Integer, nil] The unique 32-bit ID.
    # @param options [Array<Hash>] Options that can be selected.
    # @param placeholder [String, nil] Default text when no entries selected.
    # @param min_values [Integer, nil] Minimum selections.
    # @param max_values [Integer, nil] Maximum selections.
    # @param required [true, false, nil] Whether a value must be selected.
    # @yieldparam builder [SelectMenuBuilder]
    def string_select(custom_id:, id: nil, options: [], placeholder: nil, min_values: nil, max_values: nil, required: nil)
      builder = OnyxCord::Webhooks::View::SelectMenuBuilder.new(custom_id, options, placeholder, min_values, max_values, nil, select_type: :string_select, id: id, required: required)
      yield builder if block_given?
      @component = builder.to_h
    end

    alias_method :select_menu, :string_select

    # Add a user select to the label component.
    def user_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, required: nil, default_values: nil)
      @component = OnyxCord::Webhooks::View::SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, nil, select_type: :user_select, id: id, required: required, default_values: default_values).to_h
    end

    # Add a role select to the label component.
    def role_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, required: nil, default_values: nil)
      @component = OnyxCord::Webhooks::View::SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, nil, select_type: :role_select, id: id, required: required, default_values: default_values).to_h
    end

    # Add a mentionable select to the label component.
    def mentionable_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, required: nil, default_values: nil)
      @component = OnyxCord::Webhooks::View::SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, nil, select_type: :mentionable_select, id: id, required: required, default_values: default_values).to_h
    end

    # Add a channel select to the label component.
    def channel_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, required: nil, types: nil, default_values: nil)
      builder = OnyxCord::Webhooks::View::SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, nil, select_type: :channel_select, id: id, required: required, default_values: default_values).to_h
      builder[:channel_types] = types.map { |type| OnyxCord::Channel::TYPES[type] || type } if types
      @component = builder
    end

    # Add a file upload component to the label component.
    #
    # @param custom_id [String] Custom ID.
    # @param id [Integer, nil] The unique 32-bit ID.
    # @param min_values [Integer, nil] Minimum files.
    # @param max_values [Integer, nil] Maximum files.
    # @param required [true, false, nil] Whether a file is required.
    def file_upload(custom_id:, id: nil, min_values: nil, max_values: nil, required: nil)
      @component = { type: COMPONENT_TYPES[:file_upload], custom_id: custom_id, id: id, min_values: min_values, max_values: max_values, required: required }.compact
    end

    # Add a standalone checkbox component to the label component.
    #
    # @param custom_id [String] Custom ID.
    # @param id [Integer, nil] The unique 32-bit ID.
    # @param default [true, false, nil] Whether checked by default.
    def checkbox(custom_id:, id: nil, default: false)
      @component = { type: COMPONENT_TYPES[:checkbox], custom_id: custom_id, id: id, default: default }.compact
    end

    # Add a group of radio buttons to the label component.
    #
    # @param custom_id [String] Custom ID.
    # @param id [Integer, nil] The unique 32-bit ID.
    # @param buttons [Array<Hash>] Radio buttons for the group.
    # @param required [true, false, nil] Whether one must be selected.
    def radio_group(custom_id:, id: nil, buttons: [], required: nil)
      builder = GroupBuilder.new(:radio_group, custom_id, id, buttons, required)
      yield builder if block_given?
      @component = builder.to_h
    end

    # Add a group of checkboxes to the label component.
    #
    # @param custom_id [String] Custom ID.
    # @param id [Integer, nil] The unique 32-bit ID.
    # @param checkboxes [Array<Hash>] Checkboxes for the group.
    # @param min_values [Integer, nil] Minimum checkboxes.
    # @param max_values [Integer, nil] Maximum checkboxes.
    # @param required [true, false, nil] Whether one must be checked.
    def checkbox_group(custom_id:, id: nil, checkboxes: [], min_values: nil, max_values: nil, required: nil)
      builder = GroupBuilder.new(:checkbox_group, custom_id, id, checkboxes, required, min_values, max_values)
      yield builder if block_given?
      @component = builder.to_h
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:label], id: @id, label: @label, description: @description, component: @component }.compact
    end

    private

    def validate_text_input!(style, custom_id, min_length, max_length, value, placeholder)
      resolved_style = TEXT_INPUT_STYLES[style] || style
      unless VALID_TEXT_INPUT_STYLES.include?(resolved_style)
        raise ArgumentError, "Text input style must be :short (1) or :paragraph (2), got: #{style.inspect}"
      end

      if custom_id.nil? || custom_id.to_s.empty?
        raise ArgumentError, 'text_input custom_id is required'
      end

      if custom_id.to_s.length > MAX_CUSTOM_ID_LENGTH
        raise ArgumentError, "custom_id too long: #{custom_id.to_s.length} chars (max #{MAX_CUSTOM_ID_LENGTH})"
      end

      if min_length && max_length && min_length > max_length
        raise ArgumentError, "min_length (#{min_length}) must be <= max_length (#{max_length})"
      end

      if value && value.to_s.length > MAX_TEXT_INPUT_LENGTH
        raise ArgumentError, "text_input value too long: #{value.to_s.length} chars (max #{MAX_TEXT_INPUT_LENGTH})"
      end

      if placeholder && placeholder.to_s.length > 100
        raise ArgumentError, "text_input placeholder too long: #{placeholder.to_s.length} chars (max 100)"
      end
    end
  end
end
