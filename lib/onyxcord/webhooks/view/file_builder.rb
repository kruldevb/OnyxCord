# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class FileBuilder
    # Create a file component.
    # @param url [String] An `attachment://<filename>` reference to the attached file.
    # @param id [Integer, nil] The unique 32-bit ID of the file component.
    # @param spoiler [true, false] Whether or not to apply a spoiler label to the file.
    def initialize(url = nil, id: nil, spoiler: false, **kwargs)
      url = kwargs.fetch(:url, url)

      @id = id
      @file = { url: }
      @spoiler = spoiler
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:file], id: @id, spoiler: @spoiler, file: @file }.compact
    end
  end

  # A media gallery component is a gallery grid.
end
