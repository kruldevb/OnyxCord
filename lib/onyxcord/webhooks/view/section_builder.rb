# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class SectionBuilder
    # Create a section component.
    #
    # @param id [Integer, nil] The unique 32-bit ID of the section component.
    # @yieldparam builder [SectionBuilder] Yields the initialized section.
    def initialize(id: nil)
      @id = id
      @accessory = nil
      @accessory_type = nil
      @components = []

      yield self if block_given?
    end

    # Add a text display component to this section.
    #
    # @see TextDisplayBuilder#initialize
    def text_display(...)
      builder = TextDisplayBuilder.new(...)
      @components << builder
      builder
    end

    # Set the thumbnail for the section.  This is mutually exclusive with
    # {#button}.
    #
    # @param url [String] The URL to the thumbnail image.
    # @param id [Integer, nil] The unique 32-bit ID of the thumbnail.
    # @param description [String, nil] The description of the thumbnail.
    # @param spoiler [true, false] Whether to apply a spoiler label.
    def thumbnail(url:, id: nil, description: nil, spoiler: false)
      raise ArgumentError, 'Section already has a button accessory; thumbnail and button are mutually exclusive' if @accessory_type == :button

      @accessory = { type: COMPONENT_TYPES[:thumbnail], id: id, media: { url: url }, description: description, spoiler: spoiler }.compact
      @accessory_type = :thumbnail
    end

    # Set the button for the section.  This is mutually exclusive with
    # {#thumbnail}.
    #
    # @param style [Symbol, Integer] The button's style type.
    # @param id [Integer, nil] The unique 32-bit ID of the button.
    # @param label [String, nil] The text label.
    # @param emoji [#to_h, String, Integer] An emoji to attach.
    # @param custom_id [String] Custom ID for interactions.
    # @param disabled [true, false, nil] Whether the button is greyed out.
    # @param url [String, nil] The URL for link-style buttons.
    # @param sku_id [String, Integer, nil] SKU ID for premium buttons.
    def button(style:, id: nil, label: nil, emoji: nil, custom_id: nil, disabled: nil, url: nil, sku_id: nil)
      raise ArgumentError, 'Section already has a thumbnail accessory; button and thumbnail are mutually exclusive' if @accessory_type == :thumbnail

      style = BUTTON_STYLES[style] || style
      emoji = normalize_emoji(emoji)

      @accessory = {
        type: COMPONENT_TYPES[:button],
        id: id,
        label: label,
        emoji: emoji,
        style: style,
        custom_id: custom_id,
        disabled: disabled,
        url: url,
        sku_id: sku_id
      }.compact
      @accessory_type = :button
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:section], id: @id, components: @components.map(&:to_h), accessory: @accessory }.compact
    end

    private

    def normalize_emoji(emoji)
      case emoji
      when Integer
        { id: emoji.to_s }
      when String
        emoji.match?(/\A\d+\z/) ? { id: emoji } : { name: emoji }
      when Hash
        emoji
      else
        emoji&.to_h
      end
    end
  end
end
