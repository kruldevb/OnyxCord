# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Raised whenever an audit log entry is created.
  class AuditLogEntryCreateEvent < Event
    # @return [Server] the server of the audit log event.
    attr_reader :server

    # @return [AuditLogs::Entry] the entry of the audit log event.
    attr_reader :entry

    # @return [Integer] the raw action type of the audit log entry.
    attr_reader :action

    # @return [Integer] the ID of the user or bot that made the entry.
    attr_reader :user_id

    # @return [Integer, nil] the ID of the affected webhook, user, etc.
    attr_reader :target_id

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @action = data['action_type']
      @user_id = data['user_id']&.to_i
      @target_id = data['target_id']&.to_i
      @server = bot.server(data['guild_id'].to_i)
      @entry = OnyxCord::AuditLogs::Entry.new(nil, @server, @bot, data)
    end
  end

  # Event handler for GUILD_AUDIT_LOG_ENTRY_CREATE events.

  # Event handler for GUILD_AUDIT_LOG_ENTRY_CREATE events.
  class AuditLogEntryCreateEventHandler < EventHandler
    # @!visibility private
    def matches?(event)
      # Check for the proper event type.
      return false unless event.is_a?(AuditLogEntryCreateEvent)

      [
        matches_all(@attributes[:action], event) do |a, e|
          case a
          when Numeric
            a == e.action
          when String, Symbol
            a.to_sym == e.entry.action
          end
        end,

        matches_all(@attributes[:reason], event.entry) do |a, e|
          if e.reason
            case a
            when String
              a == e.reason
            when Regexp
              a.match?(e.reason)
            end
          end
        end,

        matches_all(@attributes[:user], event.user_id) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:server], event.server) do |a, e|
          a&.resolve_id == e&.resolve_id
        end,

        matches_all(@attributes[:target], event.target_id) do |a, e|
          a&.resolve_id == e&.resolve_id
        end
      ].reduce(true, &:&)
    end
  end
end
