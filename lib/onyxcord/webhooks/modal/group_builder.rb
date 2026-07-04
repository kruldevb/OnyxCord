# frozen_string_literal: true

class OnyxCord::Webhooks::Modal
  class GroupBuilder
    # @!visibility private
    def initialize(type, custom_id, id, options = [], required = nil, min_values = nil, max_values = nil)
      @id = id
      @type = type
      @custom_id = custom_id
      @options = options
      @required = required
      @min_values = min_values
      @max_values = max_values
    end

    # Add a checkbox component to the group.
    # @param value [String] The value that the checkbox represents.
    # @param label [String] The primary text of the checkbox.
    # @param description [String, nil] The description of the checkbox.
    # @param default [true, false, nil] Whether or not the checkbox should be checked by default.
    def checkbox(value:, label:, description: nil, default: nil)
      raise "Cannot add a checkbox to a #{@type}" unless @type == :checkbox_group

      @options << { value: value, label: label, description: description, default: default }.compact
    end

    # Add a radio button component to the group.
    # @param value [String] The value that the radio button represents.
    # @param label [String] The primary text of the radio button.
    # @param description [String, nil] The description of the radio button.
    # @param default [true, false, nil] Whether or not the radio button should be selected by default.
    def radio_button(value:, label:, description: nil, default: nil)
      raise "Cannot add a radio button to a #{@type}" unless @type == :radio_group

      @options << { value: value, label: label, description: description, default: default }.compact
    end

    alias_method :button, :radio_button

    # @!visibility private
    def to_h
      {
        id: @id,
        type: COMPONENT_TYPES[@type],
        custom_id: @custom_id,
        options: @options.map(&:to_h),
        required: @required,
        min_values: @min_values,
        max_values: @max_values
      }.compact
    end
  end

  # This builder is used when adding a label component to a modal.
end
