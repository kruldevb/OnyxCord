# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class SectionBuilder
    # Create a section component.
    # @param id [Integer, nil] The unique 32-bit ID of the section component.
    # @yieldparam builder [SectionBuilder] Yields the initialized section component.
    def initialize(id: nil)
      @id = id
      @accessory = nil
      @components = []

      yield self if block_given?
    end

    # Add a text display component to this section.
    # @see TextDisplayBuilder#initialize
    def text_display(...)
      @components << TextDisplayBuilder.new(...)
    end

    # Set the thumbnail for the section. This is mutually exclusive with {#button}.
    # @param url [String] The URL to the thumbnail image.
    # @param id [Integer, nil] The unique 32-bit ID of the thumbnail component.
    # @param description [String, nil] The description of the thumbnail.
    # @param spoiler [true, false] Whether or not to apply a spoiler label to the thumbnail.
    def thumbnail(url:, id: nil, description: nil, spoiler: false)
      @accessory = { type: COMPONENT_TYPES[:thumbnail], id: id, media: { url: }, description: description, spoiler: spoiler }.compact
    end

    # Set the button for the section. This is mutually exclusive with {#thumbnail}.
    # @param style [Symbol, Integer] The button's style type. See {BUTTON_STYLES}
    # @param id [Integer, nil] The unique 32-bit ID of the button component. This is not to be confused with the `custom_id`.
    # @param label [String, nil] The text label for the button. Either a label or emoji must be provided.
    # @param emoji [#to_h, String, Integer] An emoji ID, or unicode emoji to attach to the button. Can also be an object
    # that responds to `#to_h` which returns a hash in the format of `{ id: Integer, name: string }`.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    # There is a limit of 100 characters to each custom_id.
    # @param disabled [true, false] Whether this button is disabled and shown as greyed out.
    # @param url [String, nil] The URL, when using a link style button.
    def button(style:, id: nil, label: nil, emoji: nil, custom_id: nil, disabled: nil, url: nil, sku_id: nil)
      style = BUTTON_STYLES[style] || style

      emoji = case emoji
              when Integer, String
                emoji.to_i.positive? ? { id: emoji } : { name: emoji }
              else
                emoji&.to_h
              end

      @accessory = { type: COMPONENT_TYPES[:button], id: id, label: label, emoji: emoji, style: style, custom_id: custom_id, disabled: disabled, url: url, sku_id: sku_id }.compact
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:section], id: @id, components: @components.map(&:to_h), accessory: @accessory }.compact
    end
  end

  # This builder can be used to construct a container. These are similar to embeds.
end
