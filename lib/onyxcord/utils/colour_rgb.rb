# frozen_string_literal: true

module OnyxCord
  # A colour (red, green and blue values). Used for role colours. If you prefer the American spelling, the alias
  # {ColorRGB} is also available.
  class ColourRGB
    # 24-bit max value.
    MAX = 0xFFFFFF

    # @return [Integer] the red part of this colour (0-255).
    attr_reader :red

    # @return [Integer] the green part of this colour (0-255).
    attr_reader :green

    # @return [Integer] the blue part of this colour (0-255).
    attr_reader :blue

    # @return [Integer] the colour's RGB values combined into one integer.
    attr_reader :combined
    alias_method :to_i, :combined

    # Make a new colour from the combined value.
    # @param combined [String, Integer] The colour's RGB values combined into one integer or a hexadecimal string
    # @example Initialize a with a base 10 integer
    #   ColourRGB.new(7506394) #=> ColourRGB
    #   ColourRGB.new(0x7289da) #=> ColourRGB
    # @example Initialize a with a hexadecimal string
    #   ColourRGB.new('7289da') #=> ColourRGB
    #   ColourRGB.new('#7289da') #=> ColourRGB
    def initialize(combined)
      @combined = coerce_to_integer(combined)
      raise ArgumentError, "Colour value must be between 0 and 0xFFFFFF (#{MAX}), got #{@combined}" unless (0..MAX).cover?(@combined)

      @red = (@combined >> 16) & 0xFF
      @green = (@combined >> 8) & 0xFF
      @blue = @combined & 0xFF
    end

    # @return [String] the colour as a six-digit lowercase hexadecimal (e.g. "7289da").
    def hex
      format('%06x', @combined)
    end
    alias_method :hexadecimal, :hex

    # @return [String] "#7289da"
    def to_s
      "##{hex}"
    end

    def ==(other)
      return false unless other.is_a?(self.class) || other.is_a?(Integer)

      combined == (other.is_a?(Integer) ? other : other.combined)
    end

    def eql?(other)
      other.is_a?(ColourRGB) && combined == other.combined
    end

    def hash
      combined.hash
    end

    private

    def coerce_to_integer(value)
      case value
      when Integer
        value
      when String
        stripped = value.delete_prefix('#').delete_prefix('0x')
        raise ArgumentError, "Invalid colour string: #{value.inspect}" unless /\A[0-9a-fA-F]{1,6}\z/.match?(stripped)

        stripped.to_i(16)
      else
        raise ArgumentError, "Expected Integer or hex String, got #{value.class}"
      end
    end
  end

  # Alias for the class {ColourRGB}
  ColorRGB = ColourRGB
end