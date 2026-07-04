# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class ContainerBuilder
    # Create a container component.
    # @param id [Integer, nil] The unique 32-bit ID of the container component.
    # @param colour [Array, Integer, String, ColourRGB, nil] The accent colour of the container
    #   component. This argument can be passed via the American spelling (`color:`) as well.
    # @param spoiler [true, false] Whether or not to apply a spoiler label to the container component.
    # @yieldparam builder [ContainerBuilder] Yields the initialized container component.
    def initialize(id: nil, color: nil, colour: nil, spoiler: false)
      @id = id
      @spoiler = spoiler
      @components = []
      self.colour = (colour || color)

      yield self if block_given?
    end

    # Add a row component to the container.
    # @see RowBuilder#initialize
    def row(...)
      @components << RowBuilder.new(...)
    end

    # Add a file component to the container.
    # @see FileBuilder#initialize
    def file(...)
      @components << FileBuilder.new(...)
    end

    alias_method :file_display, :file

    # Add a section component to the container.
    # @see SectionBuilder#initialize
    def section(...)
      @components << SectionBuilder.new(...)
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
    def media_gallery(*items, id: nil, &block)
      @components << MediaGalleryBuilder.new(*items, id: id, &block)
    end

    # Set the color of the container.
    # @param colour [Array, Integer, String, ColourRGB, nil] The accent colour of the container component, or `nil` to clear the accent colour.
    def colour=(colour)
      @colour = case colour
                when Array
                  (colour[0] << 16) | (colour[1] << 8) | colour[2]
                when String
                  colour.delete('#').to_i(16)
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

  # @!visibility private
end
