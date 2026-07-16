# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Event for ApplicationCommand interactions.
  class ApplicationCommandEvent < InteractionCreateEvent
    # @return [Symbol] The name of the command.
    attr_reader :command_name

    # @return [Integer] The ID of the command.
    attr_reader :command_id

    # @return [Symbol, nil] The name of the subcommand group relevant to this event.
    attr_reader :subcommand_group

    # @return [Symbol, nil] The name of the subcommand relevant to this event.
    attr_reader :subcommand

    # @return [Resolved] The resolved channels, roles, users, members, and attachments for this event.
    attr_reader :resolved

    # @return [Hash<Symbol, Object>] Arguments provided to the command, mapped as `Name => Value`.
    attr_reader :options

    # @return [Integer, nil] The target of this command when it is a context command.
    attr_reader :target_id

    # @!visibility private
    def initialize(data, bot)
      super

      command_data = data['data']

      @command_id = command_data['id'].to_i
      @command_name = command_data['name'].to_sym
      @command_server_id = command_data['guild_id']

      @target_id = command_data['target_id']&.to_i
      @resolved = Resolved.new({}, {}, {}, {}, {}, {})
      process_resolved(command_data['resolved']) if command_data['resolved']

      options = command_data['options'] || []

      if options.empty?
        @options = {}
        return
      end

      case options[0]['type']
      when 2
        options = options[0]
        @subcommand_group = options['name'].to_sym
        @subcommand = options['options'][0]['name'].to_sym
        options = options['options'][0]['options']
      when 1
        options = options[0]
        @subcommand = options['name'].to_sym
        options = options['options']
      end

      @options = transform_options_hash(options || {})
    end

    # @return [true, false] Whether or not the application command that was executed
    #   has been registered globally. If this is false, then the application command
    #   that was executed is only available in the invoking server.
    def global_command?
      @command_server_id.nil?
    end

    # @return [Message, User, nil] The target of this command, for context commands.
    def target
      return nil unless @target_id

      @resolved.to_h.each_value do |data|
        return data[@target_id] if data.is_a?(Hash) && data.key?(@target_id)
      end
      nil
    end

    private

    def transform_options_hash(hash)
      hash.to_h { |opt| [opt['name'].to_sym, opt['options'] || opt['value']] }
    end
  end

  # Event handler for ApplicationCommandEvents.

  # Event handler for ApplicationCommandEvents.
  class ApplicationCommandEventHandler < EventHandler
    # @return [Hash]
    attr_reader :subcommands

    # @!visibility private
    def initialize(attributes, block)
      super

      @subcommands = {}
    end

    # @param name [Symbol, String]
    # @yieldparam [SubcommandBuilder]
    # @return [ApplicationCommandEventHandler]
    def group(name)
      raise ArgumentError, 'Unable to mix subcommands and groups' if @subcommands.any? { |n, v| n == name && v.is_a?(Proc) }

      builder = SubcommandBuilder.new(name)
      yield builder

      @subcommands.merge!(builder.to_h)
      self
    end

    # @param name [String, Symbol]
    # @yieldparam [SubcommandBuilder]
    # @return [ApplicationCommandEventHandler]
    def subcommand(name, &block)
      raise ArgumentError, 'Unable to mix subcommands and groups' if @subcommands.any? { |n, v| n == name && v.is_a?(Hash) }

      @subcommands[name.to_sym] = block

      self
    end

    # @!visibility private
    # @param event [Event]
    def call(event)
      return unless matches?(event)

      if event.subcommand_group
        unless (cmd = @subcommands.dig(event.subcommand_group, event.subcommand))
          OnyxCord::LOGGER.debug("Received an event for an unhandled subcommand `#{event.command_name} #{event.subcommand_group} #{event.subcommand}'")
          return
        end

        cmd.call(event)
      elsif event.subcommand
        unless (cmd = @subcommands[event.subcommand])
          OnyxCord::LOGGER.debug("Received an event for an unhandled subcommand `#{event.command_name} #{event.subcommand}'")
          return
        end

        cmd.call(event)
      else
        @block.call(event)
      end
    end

    # @!visibility private
    def matches?(event)
      return false unless event.is_a? ApplicationCommandEvent

      [
        matches_all(@attributes[:name], event.command_name) do |a, e|
          a.to_sym == e.to_sym
        end
      ].reduce(true, &:&)
    end
  end

  # Builder for adding subcommands to an ApplicationCommandHandler

  # Builder for adding subcommands to an ApplicationCommandHandler
  class SubcommandBuilder
    # @!visibility private
    # @param group [String, Symbol, nil]
    def initialize(group = nil)
      @group = group&.to_sym
      @subcommands = {}
    end

    # @param name [Symbol, String]
    # @yieldparam [ApplicationCommandEvent]
    def subcommand(name, &block)
      @subcommands[name.to_sym] = block
    end

    # @!visibility private
    def to_h
      @group ? { @group => @subcommands } : @subcommands
    end
  end

  # An event for when a user interacts with a component.
end
