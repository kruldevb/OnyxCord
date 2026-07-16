# frozen_string_literal: true

module OnyxCord::Commands
  # Raised when a command is registered with a name that already exists and overwrite is not allowed
  class DuplicateCommandName < RuntimeError; end

  # Command that can be called in a chain
  class Command
    # @return [Hash] the attributes the command was initialized with (frozen)
    attr_reader :attributes

    # @return [Symbol] the name of this command
    attr_reader :name

    # @!visibility private
    def initialize(name, attributes = {}, &block)
      @name = name
      @attributes = {
        permission_level: attributes[:permission_level] || 0,
        permission_message: attributes[:permission_message].is_a?(FalseClass) ? nil : (attributes[:permission_message] || "You don't have permission to execute command %name%!"),
        required_permissions: Array(attributes[:required_permissions]).freeze,
        required_roles: Array(attributes[:required_roles]).freeze,
        allowed_roles: Array(attributes[:allowed_roles]).freeze,
        channels: attributes[:channels] ? Array(attributes[:channels]).freeze : nil,
        chain_usable: attributes[:chain_usable].nil? || attributes[:chain_usable],
        help_available: attributes[:help_available].nil? || attributes[:help_available],
        description: attributes[:description] || nil,
        usage: attributes[:usage] || nil,
        arg_types: attributes[:arg_types] ? Array(attributes[:arg_types]).freeze : nil,
        parameters: attributes[:parameters] ? Array(attributes[:parameters]).freeze : nil,
        min_args: attributes[:min_args] || 0,
        max_args: attributes[:max_args] || -1,
        rate_limit_message: attributes[:rate_limit_message],
        bucket: attributes[:bucket],
        rescue: attributes[:rescue],
        aliases: Array(attributes[:aliases]).map(&:to_sym).uniq.freeze
      }.freeze

      @before_hooks = []
      @after_hooks = []
      @block = block
    end

    # Creates an isolated copy of this command for inclusion in another container.
    # Shares the block (immutable code) but duplicates hooks and frozen attributes.
    # @return [Command] a new Command with independent state
    def copy_for_container
      copied = self.class.new(@name, @attributes, &@block)
      @before_hooks.each { |h| copied.before(&h) }
      @after_hooks.each { |h| copied.after(&h) }
      copied
    end

    # Registers a before hook. The hook receives the event and arguments.
    # Return +false+ to cancel command execution.
    # @yieldparam event [CommandEvent] The event.
    # @yieldparam args [Array<String>] The command arguments.
    # @return [self]
    def before(&hook)
      @before_hooks << hook
      self
    end

    # Registers an after hook. The hook receives the event, arguments, and the result.
    # @yieldparam event [CommandEvent] The event.
    # @yieldparam args [Array<String>] The command arguments.
    # @yieldparam result [Object] The return value of the command block.
    # @return [self]
    def after(&hook)
      @after_hooks << hook
      self
    end

    # Calls this command and executes the code inside.
    # @param event [CommandEvent] The event to call the command with.
    # @param arguments [Array<String>] The attributes for the command.
    # @param chained [true, false] Whether or not this command is part of a command chain.
    # @param check_permissions [true, false] Whether the user's permission to execute the command (i.e. rate limits)
    #   should be checked.
    # @return [String] the result of the execution.
    def call(event, arguments, chained = false, check_permissions = true)
      if arguments.length < @attributes[:min_args]
        response = "Too few arguments for command `#{name}`!"
        response += "\nUsage: `#{@attributes[:usage]}`" if @attributes[:usage]
        event.respond(response)
        return
      end
      if @attributes[:max_args] >= 0 && arguments.length > @attributes[:max_args]
        response = "Too many arguments for command `#{name}`!"
        response += "\nUsage: `#{@attributes[:usage]}`" if @attributes[:usage]
        event.respond(response)
        return
      end
      if chained && !@attributes[:chain_usable]
        event.respond "Command `#{name}` cannot be used in a command chain!"
        return
      end

      if check_permissions
        rate_limited = event.bot.rate_limited?(@attributes[:bucket], event.author)
        if @attributes[:bucket] && rate_limited
          event.respond @attributes[:rate_limit_message].gsub('%time%', rate_limited.round(2).to_s) if @attributes[:rate_limit_message]
          return
        end
      end

      cancelled = @before_hooks.any? { |hook| hook.call(event, *arguments).is_a?(FalseClass) }
      return if cancelled

      result = @block.call(event, *arguments)
      event.drain_into(result)

      @after_hooks.each { |hook| hook.call(event, *arguments, result) }

      result
    rescue LocalJumpError => e # occurs when breaking
      result = e.exit_value
      event.drain_into(result)
    rescue StandardError => e # Something went wrong inside our @block!
      rescue_value = @attributes[:rescue] || event.bot.attributes[:rescue]
      if rescue_value
        event.respond(rescue_value.gsub('%exception%', e.message)) if rescue_value.is_a?(String)
        rescue_value.call(event, e) if rescue_value.respond_to?(:call)
      end

      raise e
    end
  end

  # A command that references another command
  class CommandAlias
    # @return [Symbol] the name of this alias
    attr_reader :name

    # @return [Command] the command this alias points to
    attr_reader :aliased_command

    def initialize(name, aliased_command)
      @name = name
      @aliased_command = aliased_command
    end
  end

  # Command chain, may have multiple commands, nested and commands
  class CommandChain
    # @param chain [String] The string the chain should be parsed from.
    # @param bot [Commands::Bot] The bot that executes this command chain.
    # @param subchain [true, false] Whether this chain is a sub chain of another chain.
    # @param chain [String] The string the chain should be parsed from.
    # @param bot [Commands::Bot] The bot that executes this command chain.
    # @param subchain [true, false] Whether this chain is a sub chain of another chain.
    # @param depth [Integer] Current subchain nesting depth.
    def initialize(chain, bot, subchain = false, depth: 0)
      @attributes = bot.attributes
      @chain = chain
      @bot = bot
      @subchain = subchain
      @depth = depth
    end

    # Parses the command chain itself, including sub-chains, and executes it. Executes only the command chain, without
    # its chain arguments.
    # @param event [CommandEvent] The event to execute the chain with.
    # @return [String] the result of the execution.
    def execute_bare(event)
      max_depth = @attributes[:max_subchain_depth] || 16
      if @depth > max_depth
        event.respond "Sub-chain depth limit exceeded (max #{max_depth})!"
        return ''
      end

      b_start = -1
      b_level = 0
      result = String.new
      quoted = false
      escaped = false
      hacky_delim, hacky_space, hacky_prev, hacky_newline = [0xe001, 0xe002, 0xe003, 0xe004].pack('U*').chars

      @chain.each_char.with_index do |char, index|
        # Escape character
        if char == '\\' && !escaped
          escaped = true
          next
        elsif escaped && b_level <= 0
          result << char
          escaped = false
          next
        end

        if quoted
          # Quote end
          if char == @attributes[:quote_end]
            quoted = false
            next
          end

          if b_level <= 0
            case char
            when @attributes[:chain_delimiter]
              result << hacky_delim
              next
            when @attributes[:previous]
              result << hacky_prev
              next
            when ' '
              result << hacky_space
              next
            when "\n"
              result << hacky_newline
              next
            end
          end
        else
          case char
          when @attributes[:quote_start] # Quote begin
            quoted = true
            next
          when @attributes[:sub_chain_start]
            b_start = index if b_level.zero?
            b_level += 1
          end
        end

        result << char if b_level <= 0

        next unless char == @attributes[:sub_chain_end] && !quoted

        b_level -= 1
        next unless b_level.zero?

        nested = @chain[(b_start + 1)..(index - 1)]
        subchain = CommandChain.new(nested, @bot, true, depth: @depth + 1)
        result << subchain.execute(event)
      end

      event.respond("Your subchains are mismatched! Make sure you don't have any extra #{@attributes[:sub_chain_start]}'s or #{@attributes[:sub_chain_end]}'s") unless b_level.zero?

      @chain = result

      @chain_args, @chain = divide_chain(@chain)

      prev = ''

      chain_to_split = @chain

      # Don't break if a command is called the same thing as the chain delimiter
      chain_to_split = chain_to_split.slice(1..-1) if !@attributes[:chain_delimiter].empty? && chain_to_split.start_with?(@attributes[:chain_delimiter])

      first = true
      split_chain = if @attributes[:chain_delimiter].empty?
                      [chain_to_split]
                    else
                      chain_to_split.split(@attributes[:chain_delimiter])
                    end

      # Enforce max_chain_commands limit
      max_commands = @attributes[:max_chain_commands] || 50
      if split_chain.length > max_commands
        event.respond "Command chain exceeds maximum number of commands (#{max_commands})!"
        return ''
      end

      split_chain.each do |command|
        command = @attributes[:chain_delimiter] + command if first && @chain.start_with?(@attributes[:chain_delimiter])
        first = false

        command = command.strip

        # Replace the hacky delimiter that was used inside quotes with actual delimiters
        command = command.gsub hacky_delim, @attributes[:chain_delimiter]

        first_space = command.index ' '
        command_name = first_space ? command[0..(first_space - 1)] : command
        arguments = first_space ? command[(first_space + 1)..] : ''

        # Append a previous sign if none is present
        arguments += @attributes[:previous] unless arguments.include? @attributes[:previous]
        arguments = arguments.gsub @attributes[:previous], prev

        # Replace hacky previous signs with actual ones
        arguments = arguments.gsub hacky_prev, @attributes[:previous]

        arguments = arguments.split ' '

        # Replace the hacky spaces/newlines with actual ones
        arguments.map! do |elem|
          elem.gsub(hacky_space, ' ').gsub(hacky_newline, "\n")
        end

        # Execute the command using structured result to distinguish failure from false/nil
        exec_result = @bot.execute_command_result(command_name.to_sym, event, arguments, split_chain.length > 1 || @subchain)

        # Stop chain if execution failed or was cancelled
        if exec_result.failed? || exec_result.cancelled?
          prev = ''
          break
        end

        prev = exec_result.value || ''

        # Enforce output size limit
        max_output = @attributes[:max_chain_output_bytes] || (64 * 1024)
        if prev.bytesize > max_output
          event.respond "Command chain output exceeds maximum size (#{max_output} bytes)!"
          break
        end
      end

      prev
    end

    # Divides the command chain into chain arguments and command chain, then executes them both.
    # @param event [CommandEvent] The event to execute the command with.
    # @return [String] the result of the command chain execution.
    def execute(event)
      # Dispatch to AST parser if enabled
      if @attributes[:parser] == :ast
        return OnyxCord::Commands::AstParser.execute(@chain, @bot, event)
      end

      old_chain = @chain
      @bot.debug 'Executing bare chain'
      result = execute_bare(event)

      @chain_args ||= []

      @bot.debug "Found chain args #{@chain_args}, preliminary result #{result}"

      max_repeat = @attributes[:max_chain_repeat] || 25

      @chain_args.each do |arg|
        case arg.first
        when 'repeat'
          repeat_count = [arg[1].to_i, max_repeat].min
          new_result = String.new
          executed_chain = divide_chain(old_chain).last

          repeat_count.times do
            chain_result = CommandChain.new(executed_chain, @bot, false, depth: @depth).execute(event)
            if chain_result
              # Check output size before concatenation
              max_output = @attributes[:max_chain_output_bytes] || (64 * 1024)
              if new_result.bytesize + chain_result.bytesize > max_output
                event.respond "Command chain output exceeds maximum size during repeat!"
                break
              end
              new_result << chain_result
            end
          end

          result = new_result
          # TODO: more chain arguments
        end
      end

      result
    end

    private

    def divide_chain(chain)
      chain_args_index = chain.index(@attributes[:chain_args_delim]) unless @attributes[:chain_args_delim].empty?
      chain_args = []

      if chain_args_index
        chain_args = chain[0..chain_args_index].split ','

        # Split up the arguments

        chain_args.map! do |arg|
          arg.split ' '
        end

        chain = chain[(chain_args_index + 1)..]
      end

      [chain_args, chain]
    end
  end
end
