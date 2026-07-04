# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class MediaGalleryBuilder
    # Create a media gallery component.
    # @param id [Integer, nil] The unique 32-bit ID of the media gallery component.
    # @yieldparam builder [MediaGalleryBuilder] Yields the initialized media gallery component.
    def initialize(*items, id: nil)
      @id = id
      @items = []

      items.each { |item| self.item(item) }

      yield self if block_given?
    end

    # Add a gallery item to the media gallery component.
    # @param url [String] The URL to the gallery item's media.
    # @param description [String, nil] The description of the gallery item.
    # @param spoiler [true, false] Whether or not to apply a spoiler label to the gallery item.
    def item(item = nil, url: nil, description: nil, spoiler: nil)
      url, description, spoiler = normalize_item(item, url, description, spoiler)
      raise ArgumentError, 'media gallery item requires a url' if url.nil? || url.to_s.empty?

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

  # A section allows you to group together an accessory with text display components.
end
