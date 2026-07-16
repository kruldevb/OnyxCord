# frozen_string_literal: true

require 'httpx'
require 'net/http'
require_relative 'json'
require_relative 'upload'
require 'securerandom'
require 'uri'

module OnyxCord
  module Internal
    # Modern HTTP adapter wrapping HTTPX with persistent connections, automatic
    # retries on 502, and a response interface compatible with the rest of OnyxCord.
    module HTTP
      # Lightweight response wrapper so call-sites that relied on RestClient's
      # `.body`, `.headers`, `.code` interface keep working unchanged.
      class Response
        # @return [String] the response body
        attr_reader :body

        # @return [Integer] the HTTP status code
        attr_reader :code

        # @return [Hash] the response headers (symbol keys, underscored)
        attr_reader :headers

        def initialize(httpx_response)
          @raw = httpx_response
          @body = httpx_response.body.to_s
          @code = httpx_response.respond_to?(:status) ? httpx_response.status : httpx_response.code.to_i
          response_headers = httpx_response.respond_to?(:headers) ? httpx_response.headers : httpx_response.to_hash
          @headers = normalize_headers(response_headers)
        end

        def to_s
          @body
        end

        # RestClient compatibility — some code calls `response` directly as a
        # string (implicit to_s).
        alias_method :to_str, :to_s

        private

        def normalize_headers(headers)
          transformed = headers.to_h.transform_keys do |key|
            key.to_s.tr('-', '_').downcase.to_sym
          end
          transformed.transform_values do |value|
            value.is_a?(Array) && value.size == 1 ? value.first : value
          end
        end
      end

      module_function

      POOL_OPTIONS = {
        max_connections: 50,
        max_connections_per_origin: 20,
        pool_timeout: 10
      }.freeze

      # Default timeout settings (seconds).
      DEFAULT_TIMEOUTS = {
        connect_timeout: 10,
        write_timeout: 30,
        read_timeout: 30
      }.freeze

      # The shared HTTPX session with persistent, pooled connections.
      def session
        session_mutex.synchronize do
          @session ||= HTTPX.plugin(:persistent)
                            .plugin(:follow_redirects)
                            .with(
                              fallback_protocol: 'http/1.1',
                              ssl: { alpn_protocols: ['http/1.1'] },
                              pool_options: POOL_OPTIONS,
                              timeout: DEFAULT_TIMEOUTS
                            )
        end
      end

      # Reset the HTTP session (useful for tests).
      def reset!
        session_mutex.synchronize do
          @session&.close if @session.respond_to?(:close)
        ensure
          @session = nil
        end
      end

      def session_mutex
        @session_mutex ||= Mutex.new
      end

      # Perform a raw HTTP request and return a {Response}.
      # @param type [Symbol] HTTP method (:get, :post, :put, :patch, :delete)
      # @param url [String] The full URL.
      # @param body [String, Hash, nil] The request body.
      # @param headers [Hash] Request headers.
      # @return [Response]
      def request(type, url, body = nil, **headers)
        http = session.with(headers: headers)

        raw = case type
              when :get
                http.get(url)
              when :post
                if multipart?(body)
                  # Multipart upload
                  post_multipart(url, body, headers)
                else
                  http.post(url, body: body)
                end
              when :put
                http.put(url, body: body)
              when :patch
                http.patch(url, body: body)
              when :delete
                http.delete(url)
              else
                raise ArgumentError, "Unknown HTTP method: #{type}"
              end

        # HTTPX returns an error response object on network failures
        raise raw.error if raw.is_a?(HTTPX::ErrorResponse)

        Response.new(raw)
      end

      def post_multipart(url, body, headers)
        uri = URI(url)
        boundary = "----OnyxCord#{SecureRandom.hex(12)}"
        request = Net::HTTP::Post.new(uri)
        headers.each { |key, value| request[key.to_s] = value }
        request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
        request.body_stream = MultipartStream.new(multipart_parts(body), boundary)

        Net::HTTP.start(uri.hostname, uri.port,
                        use_ssl: uri.scheme == 'https',
                        open_timeout: DEFAULT_TIMEOUTS[:connect_timeout],
                        read_timeout: DEFAULT_TIMEOUTS[:read_timeout],
                        write_timeout: DEFAULT_TIMEOUTS[:write_timeout]) do |http|
          http.request(request)
        end
      end

      # Streaming multipart body that yields chunks instead of buffering
      # the entire payload in memory.  Each read returns the next part of
      # the multipart envelope, keeping peak memory usage proportional to
      # the largest single file rather than the total upload size.
      class MultipartStream
        CHUNK_SIZE = 16 * 1024 # 16 KB

        def initialize(parts, boundary)
          @chunks = build_chunk_queue(parts, boundary)
          @index = 0
          @buffer = (+'').b
        end

        def read(length = nil, outbuf = nil)
          outbuf = outbuf.nil? ? (+'' .dup).b : outbuf.replace(+(+'').b)

          while outbuf.bytesize < length
            if @buffer.empty?
              return outbuf.empty? ? nil : outbuf if @index >= @chunks.size

              chunk = @chunks[@index]
              @index += 1

              if chunk.respond_to?(:read)
                data = chunk.read(CHUNK_SIZE)
                if data.nil? || data.empty?
                  chunk.rewind if chunk.respond_to?(:rewind)
                  next
                end
                @buffer << data
              else
                @buffer << chunk.to_s
              end
            end

            needed = length - outbuf.bytesize
            outbuf << @buffer.byteslice(0, needed)
            @buffer = @buffer.byteslice(needed..) || (+'').b
          end

          outbuf
        end

        def rewind
          @index = 0
          @buffer = (+'').b
          @chunks.each { |c| c.rewind if c.respond_to?(:rewind) }
        end

        def close
          @chunks.each { |c| c.close if c.respond_to?(:close) }
        end

        private

        def build_chunk_queue(parts, boundary)
          chunks = []
          parts.each do |part|
            chunks << "--#{boundary}\r\n"
            key = part[:name]
            if part[:filename]
              value = part[:value]
              value.rewind if value.respond_to?(:rewind)
              filename = part[:filename]
              ct = part[:content_type] || multipart_content_type(filename)
              chunks << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{filename}\"\r\n"
              chunks << "Content-Type: #{ct}\r\n\r\n"
              chunks << value
              chunks << "\r\n"
            else
              chunks << "Content-Disposition: form-data; name=\"#{key}\"\r\n\r\n"
              chunks << part[:value].to_s
              chunks << "\r\n"
            end
          end
          chunks << "--#{boundary}--\r\n"
          chunks
        end

        def multipart_content_type(filename)
          File.extname(filename).casecmp('.txt').zero? ? 'text/plain' : 'application/octet-stream'
        end
      end

      def multipart_body(body, boundary)
        output = (+'').b

        multipart_parts(body).each do |part|
          key = part[:name]
          value = part[:value]
          output << "--#{boundary}\r\n"
          if part[:filename]
            value.rewind if value.respond_to?(:rewind)
            filename = part[:filename]
            output << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{filename}\"\r\n"
            output << "Content-Type: #{part[:content_type] || multipart_content_type(filename)}\r\n\r\n"
            output << value.read.to_s
          else
            output << "Content-Disposition: form-data; name=\"#{key}\"\r\n"
            output << "\r\n"
            output << value.to_s
          end
          output << "\r\n"
        end

        output << "--#{boundary}--\r\n"
      end

      def multipart_content_type(filename)
        File.extname(filename).casecmp('.txt').zero? ? 'text/plain' : 'application/octet-stream'
      end

      def multipart?(body)
        return true if body.is_a?(Array) && body.all? { |part| part.is_a?(Hash) && part[:name] && part.key?(:value) }

        body.is_a?(Hash) && body.any? { |_, value| value.respond_to?(:read) || value.respond_to?(:path) }
      end

      def multipart_parts(body)
        return body if body.is_a?(Array)

        body.map do |key, value|
          if value.respond_to?(:read) || value.respond_to?(:path)
            upload = Upload.wrap(value)
            { name: key, value: upload, filename: upload.filename, content_type: upload.content_type }
          else
            { name: key, value: value }
          end
        end
      end

      # Convenience wrappers
      def get(url, **headers)
        request(:get, url, nil, **headers)
      end

      def post(url, body = nil, **headers)
        request(:post, url, body, **headers)
      end

      def put(url, body = nil, **headers)
        request(:put, url, body, **headers)
      end

      def patch(url, body = nil, **headers)
        request(:patch, url, body, **headers)
      end

      def delete(url, **headers)
        request(:delete, url, nil, **headers)
      end
    end
  end
end
