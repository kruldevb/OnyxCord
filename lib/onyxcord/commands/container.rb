# frozen_string_literal: true

require 'onyxcord/container'
require 'onyxcord/commands/rate_limiter'

module OnyxCord::Commands
  # This module holds a collection of commands that can be easily added to by calling the {CommandContainer#command}
  # function. Other containers can be included into it as well. This allows for modularization of command bots.
  module CommandContainer
    include RateLimiter

    # @return [Hash<Symbol, Command>] hash of canonical command names to Command objects.
    attr_reader :commands

    # @return [Hash<Symbol, Symbol>] inverted index: alias_name => canonical_command_name.
    attr_reader :aliases

    # Resolves a name (canonical or alias) to its canonical Command.
    # @param name [Symbol] The command or alias name.
    # @return [Command, nil]
    def resolve_command(name)
      return nil unless @commands

      cmd = @commands[name]
      return cmd if cmd.is_a?(Command)

      canonical = @aliases&.[](name)
      canonical ? @commands[canonical] : nil
    end

    # Returns all alias CommandAlias objects for the given canonical command name.
    # O(1) via inverted index.
    # @param name [Symbol] The canonical command name.
    # @return [Array<CommandAlias>]
    def command_aliases(name)
      return [] unless @aliases

      @aliases.filter_map { |alias_name, canonical| @commands[alias_name] if canonical == name }
    end

    # Adds a new command to the container.
    # @param name [Symbol] The name of the command to add.
    # @param attributes [Hash] The attributes to initialize the command with.
    # @option attributes [Array<Symbol>] :aliases A list of additional names for this command.
    # @option attributes [true, false] :overwrite Whether to overwrite an existing command with the same name. Default false.
    # @yield The block is executed when the command is executed.
    # @yieldparam event [CommandEvent] The event of the message that contained the command.
    # @return [Command] The command that was added.
    # @raise [DuplicateCommandName] if a command with this name already exists and overwrite is not true.
    def command(name, attributes = {}, &block)
      @commands ||= {}
      @aliases ||= {}

      if name.is_a?(Array)
        name, *aliases_from_array = name
        attributes[:aliases] = aliases_from_array if attributes[:aliases].nil?
        @logger.warn("While registering command #{name.inspect}")
        @logger.warn('Arrays for command aliases is removed. Please use `aliases` argument instead.')
      end

      overwrite = attributes.delete(:overwrite) || false

      if @commands.key?(name) && !overwrite
        raise DuplicateCommandName, "Command '#{name}' is already registered. Use `overwrite: true` to replace it."
      end

      new_command = Command.new(name, attributes, &block)

      # Clean orphan aliases from any previous command with this name
      if @commands[name].is_a?(Command)
        @commands[name].attributes[:aliases].each do |a|
          @aliases.delete(a)
          @commands.delete(a)
        end
      end

      new_command.attributes[:aliases].each do |aliased_name|
        @aliases[aliased_name] = name
        @commands[aliased_name] = CommandAlias.new(aliased_name, new_command)
      end
      @commands[name] = new_command
    end

    # Removes a specific command from this container.
    # @param name [Symbol] The command to remove.
    def remove_command(name)
      @commands ||= {}
      @aliases ||= {}

      removed = @commands.delete(name)

      if removed.is_a?(Command)
        removed.attributes[:aliases].each do |a|
          @aliases.delete(a)
          @commands.delete(a)
        end
      elsif removed.is_a?(CommandAlias)
        @aliases.delete(name)
      end

      removed
    end

    # Adds all commands from another container into this one.
    # Copies command definitions with isolated hooks and attributes to avoid shared mutable state.
    # @param container [Module] A module that `extend`s {CommandContainer} from which the commands will be added.
    def include_commands(container)
      handlers = container.instance_variable_get(:@commands) || {}
      other_aliases = container.instance_variable_get(:@aliases) || {}
      return if handlers.empty?

      @commands ||= {}
      @aliases ||= {}

      handlers.each do |name, cmd|
        next if cmd.is_a?(CommandAlias)

        copied = cmd.copy_for_container

        # Register aliases from the inverted index
        other_aliases.each do |alias_name, canonical|
          next unless canonical == name

          @aliases[alias_name] = name
          @commands[alias_name] = CommandAlias.new(alias_name, copied)
        end
        @commands[name] = copied
      end
    end

    # Registers a before or after hook on an existing command.
    # @param command_name [Symbol] The name of the command to hook.
    # @param type [:before, :after] The hook type.
    # @yieldparam event [CommandEvent] The event.
    # @yieldparam args [Array<String>] The command arguments.
    # @yieldparam result [Object] The command result (after hooks only).
    # @return [self]
    def middleware(command_name, type = :before, &hook)
      cmd = resolve_command(command_name)
      return self unless cmd.is_a?(Command)

      case type
      when :before then cmd.before(&hook)
      when :after then cmd.after(&hook)
      end
      self
    end

    # Includes another container into this one.
    # @param container [Module] An EventContainer or CommandContainer that will be included if it can.
    def include!(container)
      container_modules = container.singleton_class.included_modules

      include_events(container) if container_modules.include?(OnyxCord::EventContainer) && respond_to?(:include_events)

      if container_modules.include? OnyxCord::Commands::CommandContainer
        include_commands(container)
        include_buckets(container)
      elsif !container_modules.include? OnyxCord::EventContainer
        raise "Could not include! this particular container - ancestors: #{container_modules}"
      end
    end
  end
end
