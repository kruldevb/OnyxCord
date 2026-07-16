# frozen_string_literal: true

module OnyxCord
  # A timestamp referenced in a message via markdown.
  class TimestampMarkdown
    # Canonical symbol => specifier mapping, single source of truth.
    # Also mirrors {OnyxCord::TIMESTAMP_STYLES} for backward compatibility.
    STYLES = {
      short_time: 't',
      long_time: 'T',
      short_date: 'd',
      long_date: 'D',
      short_datetime: 'f',
      long_datetime: 'F',
      relative: 'R',
      simple_datetime: 's',
      medium_datetime: 'S',
    }.freeze

    # Reverse map: specifier => canonical symbol
    STYLE_BY_CODE = STYLES.invert.freeze

    # @return [Time] the time that the timestamp is referencing.
    attr_reader :time

    # @param time [Time, Integer]
    # @param style [Symbol, String] one of the canonical style symbols or the
    #   single-char specifier (e.g. `:relative` or `'R'`).
    def initialize(time, style)
      @time = time
      @style = normalize_style(style) || 'f'
    end

    # Get the one-letter specifier string (e.g. `f`).
    # @return [String]
    def style
      @style
    end

    # Human-readable style name (Symbol).
    # @return [Symbol, nil]
    def style_name
      STYLE_BY_CODE[@style]
    end

    # @return [String] The timestamp serialized as a string for the Discord client.
    def to_s
      OnyxCord.timestamp(@time, @style)
    end

    # @!visibility private
    def inspect
      "<TimestampMarkdown time=#{@time.to_i} style=\"#{style}\">"
    end

    # Dynamic style predicates
    STYLES.each do |name, code|
      define_method("#{name}?") do
        style == code
      end
    end

    private

    # Normalize a style argument to the single-char code.
    # Accepts:
    #  * Symbols that match {STYLES} keys (normalized to specifier).
    #  * Single-char valid specifiers.
    #  * nil → uses default.
    # Raises ArgumentError on unrecognized input.
    def normalize_style(input)
      return nil if input.nil?

      case input
      when Symbol
        code = STYLES[input]
        raise ArgumentError, "Unknown timestamp style: :#{input}" unless code

        code
      when String
        return input if STYLE_BY_CODE.key?(input)

        raise ArgumentError, "Invalid timestamp style specifier: #{input.inspect}"
      else
        raise ArgumentError, "Expected Symbol or String style, got #{input.class}"
      end
    end
  end
end