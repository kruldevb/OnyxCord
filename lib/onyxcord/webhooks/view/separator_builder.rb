# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class SeparatorBuilder
    # Create a separator component.
    # @param divider [true, false] Whether or not the separator should act as a visible barrier.
    # @param id [Integer, nil] The unique 32-bit ID of the separator component.
    # @param spacing [Symbol, Integer] The size of the separator component's padding. See {SEPARATOR_SIZES}.
    def initialize(divider:, id: nil, spacing: nil)
      @id = id
      @divider = divider
      @spacing = SEPARATOR_SIZES[spacing] || spacing
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:separator], id: @id, divider: @divider, spacing: @spacing }.compact
    end
  end

  # A file component lets you send a file via an attachment://<filename> reference.
end
