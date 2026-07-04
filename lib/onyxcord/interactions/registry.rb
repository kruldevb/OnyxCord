# frozen_string_literal: true

module OnyxCord
  module Interactions
    class Registry
      attr_reader :bot, :commands

      def initialize(bot)
        @bot = bot
        @commands = {}
      end

      def slash(name, description:, **attributes, &block)
        register(Command.chat_input(name, description: description, **attributes, &block))
      end

      def user(name, **attributes, &block)
        register(Command.user(name, **attributes, &block))
      end

      def message(name, **attributes, &block)
        register(Command.message(name, **attributes, &block))
      end

      def register(command)
        @commands[command.name] = command
        wire_handler(command)
        command
      end

      def sync!(server_id: nil, delete_unknown: false) # rubocop:disable Lint/UnusedMethodArgument
        payload = @commands.values.map(&:to_h)

        if server_id
          @bot.bulk_overwrite_guild_application_commands(server_id, payload)
        else
          @bot.bulk_overwrite_global_application_commands(payload)
        end
      end

      private

      def wire_handler(command)
        @bot.application_command(command.name) do |event|
          command.call(Context.new(event, command))
        end
      end
    end
  end
end
