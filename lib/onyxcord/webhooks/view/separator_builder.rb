# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class SeparatorBuilder
    VALID_SPACINGS = [1, 2].freeze

    # Create a separator component.
    #
    # @param divider [true, false] Whether the separator should act as a
    #   visible barrier.
    # @param id [Integer, nil] The unique 32-bit ID of the separator.
    # @param spacing [Symbol, Integer] The size of the padding.  See
    #   {SEPARATOR_SIZES}.
    def initialize(divider:, id: nil, spacing: nil)
      @id = id
      @divider = divider

      resolved_spacing = SEPARATOR_SIZES[spacing] || spacing
      if resolved_spacing && !VALID_SPACINGS.include?(resolved_spacing)
        raise ArgumentError, "Separator spacing must be 1 or 2, got: #{resolved_spacing}"
      end

      @spacing = resolved_spacing
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:separator], id: @id, divider: @divider, spacing: @spacing }.compact
    end
  end
end
