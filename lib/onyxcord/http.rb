# frozen_string_literal: true

require 'httpx'
require 'onyxcord/json'

module OnyxCord
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
        @code = httpx_response.status
        @headers = normalize_headers(httpx_response.headers)
      end

      def to_s
        @body
      end

      # RestClient compatibility — some code calls `response` directly as a
      # string (implicit to_s).
      alias_method :to_str, :to_s

      private

      def normalize_headers(headers)
        headers.to_h.transform_keys do |key|
          key.to_s.tr('-', '_').downcase.to_sym
        end
      end
    end

    module_function

    # The shared HTTPX session with persistent connections for the current thread.
    def session
      Thread.current[:onyxcord_http_session] ||= HTTPX.plugin(:persistent)
                                                 .plugin(:follow_redirects)
    end

    # Reset the HTTP session (useful for tests).
    def reset!
      Thread.current[:onyxcord_http_session] = nil
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
              if body.is_a?(Hash) && body.any? { |_, v| v.respond_to?(:read) || v.respond_to?(:path) }
                # Multipart upload
                http.plugin(:multipart).post(url, form: body)
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
