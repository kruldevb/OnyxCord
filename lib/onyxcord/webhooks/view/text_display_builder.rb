# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class TextDisplayBuilder
    # Create a text display component.
    # @param content [String] The content of the text display component.
    # @param id [Integer, nil] The unique 32-bit ID of the text display component.
    def initialize(content:, id: nil)
      @id = id
      @content = content
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:text_display], id: @id, content: @content }.compact
    end
  end

  # A separator allows you to add a barrier between components.
end
