# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class MediaGalleryBuilder
    MAX_ITEMS = 10

    # Create a media gallery component.
    #
    # @param id [Integer, nil] The unique 32-bit ID of the media gallery.
    # @yieldparam builder [MediaGalleryBuilder] Yields the initialized gallery.
    def initialize(*items, id: nil)
      @id = id
      @items = []

      items.each { |item| self.item(item) }

      yield self if block_given?
    end

    # Add a gallery item to the media gallery component.
    #
    # @param item [Hash, String, nil] A hash or URL string.
    # @param url [String, nil] The URL to the gallery item's media.
    # @param description [String, nil] The description.
    # @param spoiler [true, false] Whether to apply a spoiler label.
    def item(item = nil, url: nil, description: nil, spoiler: nil)
      url, description, spoiler = normalize_item(item, url, description, spoiler)
      raise ArgumentError, 'media gallery item requires a url' if url.nil? || url.to_s.empty?
      raise ArgumentError, "Too many media gallery items: #{@items.length + 1} (max #{MAX_ITEMS})" if @items.length >= MAX_ITEMS

      @items << { media: { url: url }, description: description, spoiler: spoiler }.compact
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:media_gallery], id: @id, items: @items }.compact
    end

    private

    def normalize_item(item, url, description, spoiler)
      if item.is_a?(Hash)
        media = item[:media] || item['media'] || {}
        url ||= item[:url] || item['url'] || media[:url] || media['url']
        description = item[:description] || item['description'] if description.nil?
        spoiler = item[:spoiler] || item['spoiler'] if spoiler.nil?
      else
        url ||= item
      end

      [url, description, spoiler.nil? ? false : spoiler]
    end
  end
end
