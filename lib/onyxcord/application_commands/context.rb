# frozen_string_literal: true

module OnyxCord
  module ApplicationCommands
    class Context
      attr_reader :event, :command

      def initialize(event, command)
        @event = event
        @command = command
      end

      def bot
        event.bot
      end

      def user
        event.user
      end

      def member
        event.user
      end

      def guild
        event.server
      end

      def guild_id
        event.server_id
      end

      def channel
        event.channel
      end

      def channel_id
        event.channel_id
      end

      def server
        event.server
      end

      def server_id
        event.server_id
      end

      def options
        return {} unless event.data

        if event.data['options']
          result = {}
          event.data['options'].each do |opt|
            key = opt['name'].to_sym
            result[key] = opt['value']
          end
          result
        else
          {}
        end
      end

      def respond(...)
        event.respond(...)
      end

      def defer(...)
        event.defer(...)
      end

      def edit_original(...)
        event.edit_response(...)
      end

      def delete_original
        event.delete_response
      end

      def followup(...)
        event.send_message(...)
      end

      class Proxy
        def initialize(command, method_name, args, kwargs, block)
          @command = command
          @method_name = method_name
          @args = args
          @kwargs = kwargs
          @block = block
        end

        def to_h
          {}
        end
      end
    end
  end
end