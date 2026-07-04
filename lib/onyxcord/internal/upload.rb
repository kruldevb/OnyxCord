# frozen_string_literal: true

module OnyxCord
  # Small wrapper for file uploads while keeping raw File/Tempfile support.
  class Upload
    attr_reader :io, :filename, :content_type

    def self.wrap(file)
      file.is_a?(self) ? file : new(file)
    end

    def initialize(io, filename: nil, content_type: nil)
      @io = io
      @filename = filename || upload_filename(io)
      @content_type = content_type
    end

    def read(...)
      @io.read(...)
    end

    def rewind
      @io.rewind if @io.respond_to?(:rewind)
    end

    def path
      @io.path if @io.respond_to?(:path)
    end

    private

    def upload_filename(io)
      path = io.path if io.respond_to?(:path)
      return File.basename(path) if path && !path.empty?

      'upload.dat'
    end
  end
end
