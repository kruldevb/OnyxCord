# frozen_string_literal: true

require 'onyxcord/utils/colour_rgb'

module OnyxCord::Webhooks
  # An embed is a rich content block attached to a webhook message.
  #
  # When serialising for *sending*, the +video+ and +provider+ fields are
  # omitted because Discord does not accept them on outbound embeds (they
  # are read-only fields returned by the API).  Nil sub-objects are also
  # stripped so that the payload remains compact.
  class Embed
    # Maximum number of fields per embed.
    MAX_FIELDS = 25

    # Maximum character length of the title.
    MAX_TITLE_LENGTH = 256

    # Maximum character length of the description.
    MAX_DESCRIPTION_LENGTH = 4096

    # Maximum character length of a field name.
    MAX_FIELD_NAME_LENGTH = 256

    # Maximum character length of a field value.
    MAX_FIELD_VALUE_LENGTH = 1024

    # Maximum character length of footer text.
    MAX_FOOTER_LENGTH = 2048

    # Maximum character length of author name.
    MAX_AUTHOR_NAME_LENGTH = 256

    def initialize(title: nil, description: nil, url: nil, timestamp: nil, colour: nil, color: nil, footer: nil,
                   image: nil, thumbnail: nil, video: nil, provider: nil, author: nil, fields: [])
      @title = title
      @description = description
      @url = url
      @timestamp = timestamp
      self.colour = colour || color
      @footer = footer
      @image = image
      @thumbnail = thumbnail
      @video = video
      @provider = provider
      @author = author
      @fields = fields
    end

    # @return [String, nil] title of the embed.
    attr_accessor :title

    # @return [String, nil] description for this embed.
    attr_accessor :description

    # @return [String, nil] URL the title should point to.
    attr_accessor :url

    # @return [Time, DateTime, String, nil] timestamp for this embed.
    #   Accepts Time, DateTime, or ISO-8601 strings.
    attr_reader :timestamp

    # Sets the timestamp.  Accepts Time, DateTime, ISO-8601 strings, or nil.
    #
    # @param value [Time, DateTime, String, nil] The timestamp.
    # @raise [ArgumentError] if the value cannot be interpreted as a time.
    def timestamp=(value)
      @timestamp = normalize_timestamp(value)
    end

    # @return [Integer, nil] the colour of the bar to the side, in decimal
    #   form.
    attr_reader :colour
    alias_method :color, :colour

    # Sets the colour using {ColourRGB} validation.
    #
    # @param value [Integer, String, Array, ColourRGB, nil] The colour.
    def colour=(value)
      if value.nil?
        @colour = nil
      elsif value.is_a?(OnyxCord::ColourRGB)
        @colour = value.combined
      elsif value.is_a?(Integer)
        OnyxCord::ColourRGB.new(value) # validates range
        @colour = value
      elsif value.is_a?(String)
        @colour = OnyxCord::ColourRGB.new(value).combined
      elsif value.is_a?(Array)
        raise ArgumentError, 'Colour tuple must have three values!' unless value.length == 3
        value.each_with_index do |c, i|
          unless c.is_a?(Integer) && c.between?(0, 255)
            raise ArgumentError, "RGB component #{i} must be an Integer in 0..255, got: #{c.inspect}"
          end
        end
        @colour = (value[0] << 16) | (value[1] << 8) | value[2]
      else
        self.colour = value.to_i
      end
    end

    alias_method :color=, :colour=

    # @return [EmbedFooter, nil] footer for this embed.
    attr_accessor :footer

    # @return [EmbedImage, nil] image for this embed.
    attr_accessor :image

    # @return [EmbedThumbnail, nil] thumbnail for this embed.
    attr_accessor :thumbnail

    # @return [EmbedAuthor, nil] author for this embed.
    attr_accessor :author

    # Add a field object to this embed.
    #
    # @param field [EmbedField] The field to add.
    def <<(field)
      @fields << field
    end

    # Convenience method to add a field to the embed without having to create
    # one manually.
    #
    # @param name [String] The field's name.
    # @param value [String] The field's value.
    # @param inline [true, false] Whether the field should be inline.
    def add_field(name: nil, value: nil, inline: nil)
      self << EmbedField.new(name: name, value: value, inline: inline)
    end

    # @return [Array<EmbedField>] the fields attached to this embed.
    attr_accessor :fields

    # Validate that this embed conforms to Discord's limits.
    #
    # @raise [ArgumentError] if any limit is exceeded.
    def validate!
      if @title && @title.length > MAX_TITLE_LENGTH
        raise ArgumentError, "Embed title too long: #{@title.length} chars (max #{MAX_TITLE_LENGTH})"
      end

      if @description && @description.length > MAX_DESCRIPTION_LENGTH
        raise ArgumentError, "Embed description too long: #{@description.length} chars (max #{MAX_DESCRIPTION_LENGTH})"
      end

      if @fields.length > MAX_FIELDS
        raise ArgumentError, "Too many fields: #{@fields.length} (max #{MAX_FIELDS})"
      end

      @fields.each_with_index do |field, i|
        if field.name && field.name.length > MAX_FIELD_NAME_LENGTH
          raise ArgumentError, "Field #{i} name too long: #{field.name.length} chars (max #{MAX_FIELD_NAME_LENGTH})"
        end
        if field.value && field.value.length > MAX_FIELD_VALUE_LENGTH
          raise ArgumentError, "Field #{i} value too long: #{field.value.length} chars (max #{MAX_FIELD_VALUE_LENGTH})"
        end
      end

      if @footer&.text && @footer.text.length > MAX_FOOTER_LENGTH
        raise ArgumentError, "Footer text too long: #{@footer.text.length} chars (max #{MAX_FOOTER_LENGTH})"
      end

      if @author&.name && @author.name.length > MAX_AUTHOR_NAME_LENGTH
        raise ArgumentError, "Author name too long: #{@author.name.length} chars (max #{MAX_AUTHOR_NAME_LENGTH})"
      end
    end

    # @return [Hash] a hash representation of this embed suitable for JSON
    #   serialisation.  Read-only fields (+video+, +provider+) and nil
    #   values are excluded.
    def to_hash
      data = {
        title: @title,
        description: @description,
        url: @url,
        timestamp: coerce_timestamp(@timestamp),
        color: @colour,
        footer: @footer&.to_hash,
        image: @image&.to_hash,
        thumbnail: @thumbnail&.to_hash,
        author: @author&.to_hash,
        fields: @fields.map(&:to_hash)
      }
      data.reject! { |_, v| v.nil? || (v.is_a?(Array) && v.empty?) }
      data
    end

    private

    # Normalise a timestamp value to a Time object in UTC.
    def normalize_timestamp(value)
      return nil if value.nil?

      case value
      when Time
        value.utc
      when DateTime
        value.to_time.utc
      when String
        Time.parse(value).utc
      else
        raise ArgumentError, "Cannot interpret #{value.class} as a timestamp"
      end
    rescue ArgumentError => e
      raise ArgumentError, "Invalid timestamp: #{value.inspect} (#{e.message})"
    end

    # Coerce a timestamp to an ISO-8601 string for the API.
    def coerce_timestamp(value)
      return nil if value.nil?
      return value.utc.iso8601 if value.respond_to?(:utc)

      value.to_s
    end
  end

  # An embed's footer will be displayed at the very bottom of an embed,
  # together with the timestamp.
  class EmbedFooter
    # @return [String, nil] text to be displayed in the footer.
    attr_accessor :text

    # @return [String, nil] URL to an icon to be shown alongside the text.
    attr_accessor :icon_url

    def initialize(text: nil, icon_url: nil)
      @text = text
      @icon_url = icon_url
    end

    def to_hash
      data = { text: @text, icon_url: @icon_url }
      data.reject! { |_, v| v.nil? }
      data
    end
  end

  # An embed's image will be displayed at the bottom, in large format.
  class EmbedImage
    # @return [String, nil] URL of the image.
    attr_accessor :url

    def initialize(url: nil)
      @url = url
    end

    def to_hash
      { url: @url }
    end
  end

  # An embed's thumbnail will be displayed at the right of the message.
  class EmbedThumbnail
    # @return [String, nil] URL of the thumbnail.
    attr_accessor :url

    def initialize(url: nil)
      @url = url
    end

    def to_hash
      { url: @url }
    end
  end

  # An embed's author will be shown at the top.
  class EmbedAuthor
    # @return [String, nil] name of the author.
    attr_accessor :name

    # @return [String, nil] URL the name should link to.
    attr_accessor :url

    # @return [String, nil] URL of the icon to be displayed next to the author.
    attr_accessor :icon_url

    def initialize(name: nil, url: nil, icon_url: nil)
      @name = name
      @url = url
      @icon_url = icon_url
    end

    def to_hash
      data = { name: @name, url: @url, icon_url: @icon_url }
      data.reject! { |_, v| v.nil? }
      data
    end
  end

  # A field is a small block of text with a header.
  class EmbedField
    # @return [String, nil] name of the field.
    attr_accessor :name

    # @return [String, nil] value of the field.
    attr_accessor :value

    # @return [true, false] whether the field should be displayed inline.
    attr_accessor :inline

    def initialize(name: nil, value: nil, inline: false)
      @name = name
      @value = value
      @inline = inline
    end

    def to_hash
      { name: @name, value: @value, inline: @inline }
    end
  end
end
