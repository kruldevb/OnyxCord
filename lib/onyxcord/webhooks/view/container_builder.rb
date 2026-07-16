# frozen_string_literal: true

require 'onyxcord/utils/colour_rgb'

class OnyxCord::Webhooks::View
  class ContainerBuilder
    # Create a container component.
    #
    # @param id [Integer, nil] The unique 32-bit ID of the container component.
    # @param color [Array, Integer, String, ColourRGB, nil] The accent colour.
    # @param spoiler [true, false] Whether to apply a spoiler label.
    # @yieldparam builder [ContainerBuilder] Yields the initialized container.
    def initialize(id: nil, color: nil, colour: nil, spoiler: false)
      @id = id
      @spoiler = spoiler
      @components = []
      self.colour = (colour || color)

      yield self if block_given?
    end

    # Add a row component to the container.
    # @see RowBuilder#initialize
    def row(id: nil, &block)
      builder = RowBuilder.new(id: id, &block)
      @components << builder
      builder
    end

    # Add a file component to the container.
    # @see FileBuilder#initialize
    def file(...)
      @components << FileBuilder.new(...)
    end

    alias_method :file_display, :file

    # Add a section component to the container.
    # @see SectionBuilder#initialize
    def section(id: nil, &block)
      builder = SectionBuilder.new(id: id, &block)
      @components << builder
      builder
    end

    # Add a separator component to the container.
    # @see SeparatorBuilder#initialize
    def separator(...)
      @components << SeparatorBuilder.new(...)
    end

    # Add a text display component to the container.
    # @see TextDisplayBuilder#initialize
    def text_display(...)
      @components << TextDisplayBuilder.new(...)
    end

    # Add a media gallery component to the container.
    # @see MediaGalleryBuilder#initialize
    def media_gallery(*items, id: nil)
      @components << MediaGalleryBuilder.new(*items, id: id)
    end

    # Set the color of the container.
    #
    # @param colour [Array, Integer, String, ColourRGB, nil] The accent
    #   colour, or +nil+ to clear.
    def colour=(colour)
      @colour = case colour
                when OnyxCord::ColourRGB
                  colour.combined
                when Integer
                  OnyxCord::ColourRGB.new(colour) # validates range
                  colour
                when String
                  OnyxCord::ColourRGB.new(colour).combined
                when Array
                  raise ArgumentError, 'Colour tuple must have three values!' unless colour.length == 3
                  colour.each_with_index do |c, i|
                    unless c.is_a?(Integer) && c.between?(0, 255)
                      raise ArgumentError, "RGB component #{i} must be an Integer in 0..255, got: #{c.inspect}"
                    end
                  end
                  (colour[0] << 16) | (colour[1] << 8) | colour[2]
                when nil
                  nil
                else
                  colour&.to_i
                end
    end

    alias_method :color=, :colour=

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:container], id: @id, accent_color: @colour, spoiler: @spoiler, components: @components.map(&:to_h) }.compact
    end
  end
end
