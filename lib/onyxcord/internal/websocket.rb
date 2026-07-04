# frozen_string_literal: true

require_relative 'async_runtime'
require 'async/http/endpoint'
require 'async/http/protocol/http11'
require 'async/websocket/client'

module OnyxCord
  module Internal
    class WebSocket
      attr_reader :connected

      alias_method :connected?, :connected

      def initialize(host, open_handler, message_handler, error_handler, close_handler)
        @host = host
        @open_handler = open_handler
        @message_handler = message_handler
        @error_handler = error_handler
        @close_handler = close_handler

        @connection = nil
        @connected = false

        connect
      end

      def send(data)
        return unless @connection

        data = data.to_json if data.is_a?(Hash)
        @connection.write(Protocol::WebSocket::TextMessage.generate(data))
        @connection.flush
      rescue StandardError => e
        @error_handler&.call(e)
      end

      def close
        @connected = false
        @connection&.close
      rescue StandardError
        # Ignore errors on close
      end

      private

      def connect
        endpoint = websocket_endpoint(@host)

        @task = AsyncRuntime.async do
          Async::WebSocket::Client.connect(endpoint, extensions: nil) do |connection|
            @connection = connection
            @connected = true
            @open_handler&.call

            while (message = connection.read)
              @message_handler&.call(message.to_str)
            end
          rescue StandardError => e
            @error_handler&.call(e)
          ensure
            @connected = false
            @close_handler&.call(nil)
          end
        end
      rescue StandardError => e
        @error_handler&.call(e)
      end

      def websocket_endpoint(url)
        Async::HTTP::Endpoint.parse(
          url,
          protocol: Async::HTTP::Protocol::HTTP11,
          alpn_protocols: ['http/1.1']
        )
      end
    end
  end
end
