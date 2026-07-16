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

      def primary_entry_point(name, description:, **attributes, &block)
        register(Command.primary_entry_point(name, description: description, **attributes, &block))
      end

      # INT-0106: registro por chave [type, name]
      def register(command)
        type_int = Command::TYPES[command.type]
        key = [type_int, command.name]
        @commands[key] = command
        wire_handler(command)
        command
      end

      # INT-0304: sincronização no-op — compara payload canônico e ignora se idêntico
      def sync!(server_id: nil, delete_unknown: true, dry_run: false)
        payload = @commands.values.map { |cmd| cmd.to_h(server_id: server_id) }

        return dry_run_summary(server_id, payload) if dry_run

        if delete_unknown
          bulk_overwrite(server_id, payload)
        else
          sync_preserve(server_id, payload)
        end
      end

      # INT-0304: retorna true se sync seria no-op (iguais)
      def noop?(server_id: nil)
        remote = fetch_remote_commands(server_id)
        local = @commands.values.map { |cmd| canonical(cmd, server_id) }

        remote.all? do |r|
          local.any? { |l| canonical_eq(l, r) }
        end && local.all? do |l|
          remote.any? { |r| canonical_eq(l, r) }
        end
      rescue StandardError
        false
      end

      # INT-0107: bloquear sync destrutivo de registry vazio sem flag explicita
      def sync_safe!(server_id: nil, delete_unknown: true)
        if delete_unknown && @commands.empty?
          raise ArgumentError, 'Cannot wipe commands with empty registry - use bulk_overwrite! explicitly'
        end
        sync!(server_id: server_id, delete_unknown: delete_unknown)
      end

      # Sincroniza todos os tipos substituindo a lista completa do escopo
      def bulk_overwrite!
        @bot.bulk_overwrite_global_application_commands(@commands.values.map { |c| c.to_h(server_id: nil) })
      end

      def bulk_overwrite_guild!(server_id)
        @bot.bulk_overwrite_guild_application_commands(server_id, @commands.values.map { |c| c.to_h(server_id: server_id) })
      end

      private

      def wire_handler(command)
        type_int = Command::TYPES[command.type]
        @bot.application_command(command.name, type: type_int) do |event|
          context = Context.new(event, command)
          dispatch(command, context, event)
        end
      end

      # INT-0104: despacho de executores por subcomando
      def dispatch(command, context, event)
        if event.respond_to?(:subcommand_group) && event.subcommand_group
          group = command.find_subcommand(event.subcommand_group)
          if group && (sub = group.options.find { |o| o.name == event.subcommand.to_s })
            sub.executor&.call(context)
          else
            command.root_executor&.call(context)
          end
        elsif event.respond_to?(:subcommand) && event.subcommand
          sub = command.find_subcommand(event.subcommand)
          if sub
            sub.executor&.call(context)
          else
            command.root_executor&.call(context)
          end
        else
          command.call(context)
        end
      end

      def bulk_overwrite(server_id, payload)
        if server_id
          @bot.bulk_overwrite_guild_application_commands(server_id, payload)
        else
          @bot.bulk_overwrite_global_application_commands(payload)
        end
      end

      def sync_preserve(server_id, payload)
        remote = fetch_remote_commands(server_id)
        existing_by_name = remote.each_with_object({}) { |c| existing_by_name[c['name']] = c }

        retained = existing_by_name.values.select do |c|
          !managed_by_us?(c, payload)
        end

        new_set = payload + retained.map { |c| compact_payload(c) }

        bulk_overwrite(server_id, new_set)
      end

      def fetch_remote_commands(server_id)
        commands = if server_id
                     @bot.get_application_commands(server_id: server_id)
                   else
                     @bot.get_application_commands
                   end
        commands.map { |cmd| extract_command_attrs(cmd) }
      rescue StandardError
        []
      end

      def managed_by_us?(remote, local_payload)
        local_payload.any? { |p| p[:name] == remote[:name] }
      end

      def extract_command_attrs(cmd)
        {
          name: cmd.name,
          type: cmd.is_a?(Hash) ? cmd['type'] : OnyxCord::Interactions::Command::TYPES[:chat_input],
          description: cmd.respond_to?(:description) ? cmd.description : '',
          options: cmd.respond_to?(:options) ? cmd.options : [],
          default_member_permissions: cmd.respond_to?(:default_permission) ? cmd.default_permission : nil
        }.compact
      end

      def dry_run_summary(server_id, payload)
        remote = fetch_remote_commands(server_id)
        remote_names = remote.map { |c| c[:name] }.to_set
        local_names = payload.map { |p| p[:name] }.to_set

        {
          create: local_names - remote_names,
          update: local_names & remote_names,
          delete: remote_names - local_names,
          server_id: server_id,
          total_local: payload.size,
          total_remote: remote.size
        }
      end

      # INT-0304: payload canônico (ignora id, version, etc.)
      def canonical(cmd, server_id)
        h = cmd.to_h(server_id: server_id)
        h.reject { |k, _| %i[id version application_id guild_id].include?(k) }
      end

      def canonical_eq(a, b)
        a[:name] == b[:name] && a[:type] == b[:type]
      end
    end
  end
end
