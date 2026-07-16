# frozen_string_literal: true

class OnyxCord::Commands::Bot
  # Structured result of command execution for internal chain handling.
  # status: :executed, :skipped, :cancelled, :failed
  # value: the return value of the command (nil if not executed)
  # reason: symbol describing why (nil if executed), e.g. :no_permission, :rate_limited, :unknown_command, :bad_channel, :hook_cancelled
  ExecutionResult = Data.define(:status, :value, :reason) do
    def executed?
      status == :executed
    end

    def failed?
      status == :failed
    end

    def cancelled?
      status == :cancelled
    end

    def skipped?
      status == :skipped
    end
  end

  module Execution
    # Returns all aliases for the command with the given name.
    # Delegates to CommandContainer#command_aliases (O(1) inverted index).
    # @param name [Symbol] the name of the `Command`
    # @return [Array<CommandAlias>]
    def command_aliases(name)
      super(name)
    end

    # Executes a particular command on the bot.
    # @param name [Symbol] The command to execute.
    # @param event [CommandEvent] The event to pass to the command.
    # @param arguments [Array<String>] The arguments to pass to the command.
    # @param chained [true, false] Whether or not it should be executed as part of a command chain.
    # @param check_permissions [true, false] Whether permission parameters should be checked.
    # @return [String, nil] the command's result, if there is any.
    def execute_command(name, event, arguments, chained = false, check_permissions = true)
      execute_command_result(name, event, arguments, chained, check_permissions).value
    end

    # Internal structured execution that returns an ExecutionResult.
    # Used by command chains to distinguish between failure and a command returning false/nil.
    # @return [ExecutionResult]
    def execute_command_result(name, event, arguments, chained = false, check_permissions = true)
      debug("Executing command #{name} server=#{event.respond_to?(:server) && event.server&.id} user=#{event.respond_to?(:author) && event.author&.id}")
      return ExecutionResult.new(:failed, nil, :no_commands) unless @commands

      command = resolve_command(name)

      unless !check_permissions || channels?(event.channel, @attributes[:channels]) ||
             (command && !command.attributes[:channels].nil?)
        return ExecutionResult.new(:failed, nil, :bad_channel)
      end

      unless command
        if @attributes[:command_doesnt_exist_message]
          message = @attributes[:command_doesnt_exist_message]
          message = message.call(event) if message.respond_to?(:call)
          event.respond message.gsub('%command%', name.to_s) if message
        end
        return ExecutionResult.new(:failed, nil, :unknown_command)
      end

      unless !check_permissions || channels?(event.channel, command.attributes[:channels])
        return ExecutionResult.new(:failed, nil, :bad_channel)
      end

      if check_permissions
        unless permission?(event.author, command.attributes[:permission_level], event.server) &&
               required_permissions?(event.author, command.attributes[:required_permissions], event.channel) &&
               required_roles?(event.author, command.attributes[:required_roles]) &&
               allowed_roles?(event.author, command.attributes[:allowed_roles])
          event.respond command.attributes[:permission_message].gsub('%name%', name.to_s) if command.attributes[:permission_message]
          return ExecutionResult.new(:failed, nil, :no_permission)
        end
      end

      arguments = arg_check(arguments, command.attributes[:arg_types], event.server) if check_permissions
      event.command = command
      result = command.call(event, arguments, chained, check_permissions)
      ExecutionResult.new(:executed, stringify(result), nil)
    rescue OnyxCord::Errors::NoPermission
      event.respond @attributes[:no_permission_message] unless @attributes[:no_permission_message].nil?
      ExecutionResult.new(:failed, nil, :no_permission)
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
