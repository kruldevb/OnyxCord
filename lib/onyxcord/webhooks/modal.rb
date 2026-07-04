# frozen_string_literal: true

# Modal component builder.
class OnyxCord::Webhooks::Modal
  # A mapping of names to types of components usable in a modal.
  COMPONENT_TYPES = {
    action_row: 1,
    string_select: 3,
    text_input: 4,
    user_select: 5,
    role_select: 6,
    mentionable_select: 7,
    channel_select: 8,
    text_display: 10,
    label: 18,
    file_upload: 19,
    radio_group: 21,
    checkbox_group: 22,
    checkbox: 23
  }.freeze

  require 'onyxcord/webhooks/modal/group_builder'
  require 'onyxcord/webhooks/modal/label_builder'

  def initialize
    @components = []

    yield self if block_given?
  end

  # @!visibility private
  def to_a
    @components.map(&:to_h)
  end

  # Add a label component to the view.
  # @see LabelBuilder#initialize
  def label(...)
    @components << LabelBuilder.new(...)
  end

  # Add a legacy action row to the modal.
  def row(id: nil)
    @components << LegacyRowBuilder.new(id: id) { |row| yield row }
  end

  # Add a text display component to the view.
  # @see Webhooks::View::TextDisplayBuilder#initialize
  def text_display(...)
    @components << OnyxCord::Webhooks::View::TextDisplayBuilder.new(...)
  end

  class LegacyRowBuilder
    def initialize(id: nil)
      @id = id
      @components = []

      yield self if block_given?
    end

    def text_input(style:, custom_id:, id: nil, min_length: nil, max_length: nil, required: nil, value: nil, placeholder: nil, label: nil)
      @components << {
        type: COMPONENT_TYPES[:text_input],
        custom_id: custom_id,
        id: id,
        label: label,
        style: LabelBuilder::TEXT_INPUT_STYLES[style] || style,
        min_length: min_length,
        max_length: max_length,
        required: required,
        value: value,
        placeholder: placeholder
      }.compact
    end

    def file_upload(custom_id:, id: nil, min_values: nil, max_values: nil, required: nil)
      @components << {
        type: COMPONENT_TYPES[:file_upload],
        custom_id: custom_id,
        id: id,
        min_values: min_values,
        max_values: max_values,
        required: required
      }.compact
    end

    def to_h
      { type: COMPONENT_TYPES[:action_row], id: @id, components: @components }.compact
    end
  end
end
