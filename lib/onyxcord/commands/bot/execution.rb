# frozen_string_literal: true

class OnyxCord::Commands::Bot
  module Execution
    # Returns all aliases for the command with the given name
    # @param name [Symbol] the name of the `Command`
    # @return [Array<CommandAlias>]
    def command_aliases(name)
      commands.values.select do |command|
        command.is_a?(OnyxCord::Commands::CommandAlias) && command.aliased_command.name == name
      end
    end

    # Executes a particular command on the bot. Mostly useful for internal stuff, but one can never know.
    # @param name [Symbol] The command to execute.
    # @param event [CommandEvent] The event to pass to the command.
    # @param arguments [Array<String>] The arguments to pass to the command.
    # @param chained [true, false] Whether or not it should be executed as part of a command chain. If this is false,
    #   commands that have chain_usable set to false will not work.
    # @param check_permissions [true, false] Whether permission parameters such as `required_permission` or
    #   `permission_level` should be checked.
    # @return [String, nil] the command's result, if there is any.

    def execute_command(name, event, arguments, chained = false, check_permissions = true)
      debug("Executing command #{name} with arguments #{arguments}")
      return unless @commands

      command = @commands[name]
      command = command.aliased_command if command.is_a?(OnyxCord::Commands::CommandAlias)
      return unless !check_permissions || channels?(event.channel, @attributes[:channels]) ||
                    (command && !command.attributes[:channels].nil?)

      unless command
        if @attributes[:command_doesnt_exist_message]
          message = @attributes[:command_doesnt_exist_message]
          message = message.call(event) if message.respond_to?(:call)
          event.respond message.gsub('%command%', name.to_s) if message
        end
        return
      end
      return unless !check_permissions || channels?(event.channel, command.attributes[:channels])

      arguments = arg_check(arguments, command.attributes[:arg_types], event.server) if check_permissions
      if (check_permissions &&
         permission?(event.author, command.attributes[:permission_level], event.server) &&
         required_permissions?(event.author, command.attributes[:required_permissions], event.channel) &&
         required_roles?(event.author, command.attributes[:required_roles]) &&
         allowed_roles?(event.author, command.attributes[:allowed_roles])) ||
         !check_permissions
        event.command = command
        result = command.call(event, arguments, chained, check_permissions)
        stringify(result)
      else
        event.respond command.attributes[:permission_message].gsub('%name%', name.to_s) if command.attributes[:permission_message]
        nil
      end
    rescue OnyxCord::Errors::NoPermission
      event.respond @attributes[:no_permission_message] unless @attributes[:no_permission_message].nil?
      raise
    end

    # Transforms an array of string arguments based on types array.
    # For example, `['1', '10..14']` with types `[Integer, Range]` would turn into `[1, 10..14]`.

    def arg_check(args, types = nil, server = nil)
      return args unless types

      args.each_with_index.map do |arg, i|
        next arg if types[i].nil? || types[i] == String

        if types[i] == Integer
          Integer(arg, 10, exception: false)
        elsif types[i] == Float
          Float(arg, exception: false)
        elsif types[i] == Time
          begin
            Time.parse arg
          rescue ArgumentError
            nil
          end
        elsif [TrueClass, FalseClass].include?(types[i])
          if arg.casecmp('true').zero? || arg.downcase.start_with?('y')
            true
          elsif arg.casecmp('false').zero? || arg.downcase.start_with?('n')
            false
          end
        elsif types[i] == Symbol
          arg.to_sym
        elsif types[i] == Encoding
          begin
            Encoding.find arg
          rescue ArgumentError
            nil
          end
        elsif types[i] == Regexp
          begin
            Regexp.new arg
          rescue ArgumentError
            nil
          end
        elsif types[i] == Rational
          Rational(arg, exception: false)
        elsif types[i] == Range
          begin
            if arg.include? '...'
              Range.new(*arg.split('...').map(&:to_i), true)
            elsif arg.include? '..'
              Range.new(*arg.split('..').map(&:to_i))
            end
          rescue ArgumentError
            nil
          end
        elsif types[i] == NilClass
          nil
        elsif [OnyxCord::User, OnyxCord::Role, OnyxCord::Emoji].include? types[i]
          result = parse_mention arg, server
          result if result.instance_of? types[i]
        elsif types[i] == OnyxCord::Invite
          resolve_invite_code arg
        elsif types[i].respond_to?(:from_argument)
          begin
            types[i].from_argument arg
          rescue StandardError
            nil
          end
        else
          raise ArgumentError, "#{types[i]} doesn't implement from_argument"
        end
      end
    end

    # Executes a command in a simple manner, without command chains or permissions.
    # @param chain [String] The command with its arguments separated by spaces.
    # @param event [CommandEvent] The event to pass to the command.
    # @return [String, nil] the command's result, if there is any.

    def simple_execute(chain, event)
      return nil if chain.empty?

      args = chain.split(' ')
      execute_command(args[0].to_sym, event, args[1..])
    end

    # Sets the permission level of a user
    # @param id [Integer] the ID of the user whose level to set
    # @param level [Integer] the level to set the permission to

    private

    def execute_chain(chain, event)
      Async do
        debug("Parsing command chain #{chain}")
        result = @attributes[:advanced_functionality] ? OnyxCord::Commands::CommandChain.new(chain, self).execute(event) : simple_execute(chain, event)
        result = event.drain_into(result)

        if event.file
          event.send_file(event.file, caption: result)
        else
          event.respond result unless result.nil? || result.empty?
        end
      rescue StandardError => e
        log_exception(e)
      end
    end

    # Turns the object into a string, using to_s by default

    def stringify(object)
      return '' if object.is_a? OnyxCord::Message

      object.to_s
    end
  end
end
