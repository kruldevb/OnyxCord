# frozen_string_literal: true

module OnyxCord
  module Interactions
    class Context
      attr_reader :event, :command

      def initialize(event, command)
        @event = event
        @command = command
        @options_snapshot = nil
      end

      def bot
        event.bot
      end

      def user
        event.user
      end

      def member
        return unless event.respond_to?(:interaction) && event.interaction
        return unless event.interaction.user
        event.interaction.user if event.interaction.user.is_a?(OnyxCord::Member)
      end

      def guild
        event.server
      end

      alias_method :server, :guild

      def guild_id
        event.server_id
      end

      alias_method :server_id, :guild_id

      def channel
        event.channel
      end

      def channel_id
        event.channel_id
      end

      def locale
        event.user_locale
      end

      def guild_locale
        event.server_locale
      end

      # INT-0209: USER/MESSAGE complements
      def target
        event.target if event.respond_to?(:target)
      end

      def target_id
        event.target_id if event.respond_to?(:target_id)
      end

      def command_id
        event.command_id if event.respond_to?(:command_id)
      end

      def command_type
        event.data && event.data['type'] ? event.data['type'] : 1
      end

      def subcommand
        event.subcommand if event.respond_to?(:subcommand)
      end

      def subcommand_group
        event.subcommand_group if event.respond_to?(:subcommand_group)
      end

      # INT-0105: opcões recursivas via rota + resolved sem REST
      # INT-0301: memorizada
      def options
        return @options_snapshot if @options_snapshot

        result = compute_options
        @options_snapshot = result.freeze
        @options_snapshot
      end

      def resolved
        event.resolved if event.respond_to?(:resolved)
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

      private

      def compute_options
        return {} unless event.respond_to?(:data) && event.data

        cmd_data = event.data
        opts = cmd_data['options'] || []

        return {} if opts.empty?

        case opts[0]['type']
        when 2
          # subcommand_group -> subcommand -> folha
          group = opts[0]
          sub = group['options']&.first
          return {} unless sub
          build_leaf_options(sub['options'] || [])
        when 1
          sub = opts[0]
          build_leaf_options(sub['options'] || [])
        else
          build_leaf_options(opts)
        end
      end

      def build_leaf_options(opts)
        result = {}
        opts.each do |opt|
          key = opt['name'].to_sym
          val = opt.key?('options') ? opt['options'] : opt['value']
          result[key] = resolve_value(opt, val)
        end
        result
      end

      # INT-0105: converter USER/ROLE/CHANNEL/MENTIONABLE/ATTACHMENT usando resolved
      def resolve_value(opt, raw_value)
        return raw_value unless resolved

        case opt['type']
        when 6   # USER
          uid = raw_value.to_i
          member = resolved[:members][uid] if resolved.respond_to?(:[])
          user = resolved[:users][uid]
          member || user || raw_value
        when 8   # ROLE
          resolved[:roles][raw_value.to_i] || raw_value
        when 7   # CHANNEL
          resolved[:channels][raw_value.to_i] || raw_value
        when 9   # MENTIONABLE
          uid = raw_value.to_i
          resolved[:users][uid] || resolved[:roles][uid] || resolved[:members][uid] || raw_value
        when 11  # ATTACHMENT
          resolved[:attachments][raw_value.to_i] || raw_value
        else
          raw_value
        end
      end
    end
  end
end
