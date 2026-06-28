# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'

module OnyxCord
  # Wrapper around async-websocket that provides the same callback-based
  # interface used by the Gateway and Voice subsystems. This replaces the
  # previous websocket-client-simple implementation.
  class WebSocket
    # @return [Boolean] whether the connection is currently open.
    attr_reader :connected

    alias_method :connected?, :connected

    # Creates a new WebSocket wrapper.
    # @param host [String]            The `wss://` endpoint URL to connect to.
    # @param open_handler [Proc]      Called once the connection is established.
    # @param message_handler [Proc]   Called for every text frame received.
    # @param error_handler [Proc]     Called when an error occurs.
    # @param close_handler [Proc]     Called when the connection closes.
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

    # Send a text message over the WebSocket.
    # @param data [String, Hash] Data to send. Hashes are JSON-encoded automatically.
    def send(data)
      return unless @connection

      data = data.to_json if data.is_a?(Hash)
      @connection.write(Protocol::WebSocket::TextMessage.generate(data))
      @connection.flush
    rescue StandardError => e
      @error_handler&.call(e)
    end

    # Cleanly close the connection.
    def close
      @connected = false
      @connection&.close
    rescue StandardError
      # Ignore errors on close
    end

    private

    def connect
      endpoint = Async::HTTP::Endpoint.parse(@host)

      Async do
        Async::WebSocket::Client.connect(endpoint) do |connection|
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
  end
end
