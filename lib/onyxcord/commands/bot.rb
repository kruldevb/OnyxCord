# frozen_string_literal: true

require 'onyxcord/bot'
require 'onyxcord/models'
require 'onyxcord/commands/parser'
require 'onyxcord/commands/events'
require 'onyxcord/commands/container'
require 'onyxcord/commands/rate_limiter'
require 'time'

# Specialized bot to run commands

module OnyxCord::Commands
  # Bot that supports commands and command chains
  class Bot < OnyxCord::Bot
    # @return [Hash] this bot's attributes.
    attr_reader :attributes

    # @return [String, Array<String>, #call] the prefix commands are triggered with.
    # @see #initialize
    attr_reader :prefix

    DEFAULT_DELIMITERS = {
      previous: '~',
      chain_delimiter: '>',
      chain_args_delim: ':',
      sub_chain_start: '[',
      sub_chain_end: ']',
      quote_start: '"',
      quote_end: '"'
    }.freeze

    include CommandContainer
    require 'onyxcord/commands/bot/execution'
    include Execution
    require 'onyxcord/commands/bot/permissions'
    include Permissions
    require 'onyxcord/commands/bot/channels'
    include Channels
    require 'onyxcord/commands/bot/message_dispatch'
    include MessageDispatch

    # Creates a new Commands::Bot and logs in to Discord.
    # @param attributes [Hash] The attributes to initialize the Commands::Bot with.
    # @see OnyxCord::Bot#initialize OnyxCord::Bot#initialize for other attributes that should be used to create the underlying regular bot.
    # @option attributes [String, Array<String>, #call] :prefix The prefix that should trigger this bot's commands. It
    #   can be:
    #
    #   * Any string (including the empty string). This has the effect that if a message starts with the prefix, the
    #     prefix will be stripped and the rest of the chain will be parsed as a command chain. Note that it will be
    #     literal - if the prefix is "hi" then the corresponding trigger string for a command called "test" would be
    #     "hitest". Don't forget to put spaces in if you need them!
    #   * An array of prefixes. Those will behave similarly to setting one string as a prefix, but instead of only one
    #     string, any of the strings in the array can be used.
    #   * Something Proc-like (responds to :call) that takes a {Message} object as an argument and returns either
    #     the command chain in raw form or `nil` if the given message shouldn't be parsed. This can be used to make more
    #     complicated dynamic prefixes (e. g. based on server), or even something else entirely (suffixes, or most
    #     adventurous, infixes).
    # @option attributes [true, false] :advanced_functionality Whether to enable advanced functionality (very powerful
    #   way to nest commands into chains, see https://github.com/kruldevb/OnyxCord/wiki/Commands#command-chain-syntax
    #   for info. Default is false.
    # @option attributes [Symbol, Array<Symbol>, false] :help_command The name of the command that displays info for
    #   other commands. Use an array if you want to have aliases. Default is "help". If none should be created, use
    #   `false` as the value.
    # @option attributes [String, #call] :command_doesnt_exist_message The message that should be displayed if a user attempts
    #   to use a command that does not exist. If none is specified, no message will be displayed. In the message, you
    #   can use the string '%command%' that will be replaced with the name of the command. Anything responding to call
    #   such as a proc will be called with the event, and is expected to return a String or nil.
    # @option attributes [String] :no_permission_message The message to be displayed when `NoPermission` error is raised.
    # @option attributes [true, false] :spaces_allowed Whether spaces are allowed to occur between the prefix and the
    #   command. Default is false.
    # @option attributes [true, false] :webhook_commands Whether messages sent by webhooks are allowed to trigger
    #   commands. Default is true.
    # @option attributes [Array<String, Integer, Channel>] :channels The channels this command bot accepts commands on.
    #   Superseded if a command has a 'channels' attribute.
    # @option attributes [String] :previous Character that should designate the result of the previous command in
    #   a command chain (see :advanced_functionality). Default is '~'. Set to an empty string to disable.
    # @option attributes [String] :chain_delimiter Character that should designate that a new command begins in the
    #   command chain (see :advanced_functionality). Default is '>'. Set to an empty string to disable.
    # @option attributes [String] :chain_args_delim Character that should separate the command chain arguments from the
    #   chain itself (see :advanced_functionality). Default is ':'. Set to an empty string to disable.
    # @option attributes [String] :sub_chain_start Character that should start a sub-chain (see
    #   :advanced_functionality). Default is '['. Set to an empty string to disable.
    # @option attributes [String] :sub_chain_end Character that should end a sub-chain (see
    #   :advanced_functionality). Default is ']'. Set to an empty string to disable.
    # @option attributes [String] :quote_start Character that should start a quoted string (see
    #   :advanced_functionality). Default is '"'. Set to an empty string to disable.
    # @option attributes [String] :quote_end Character that should end a quoted string (see
    #   :advanced_functionality). Default is '"' or the same as :quote_start. Set to an empty string to disable.
    # @option attributes [true, false] :ignore_bots Whether the bot should ignore bot accounts or not. Default is false.
    def initialize(**attributes)
      super(
        log_mode: attributes[:log_mode],
        token: attributes[:token],
        client_id: attributes[:client_id],
        type: attributes[:type],
        name: attributes[:name],
        fancy_log: attributes[:fancy_log],
        suppress_ready: attributes[:suppress_ready],
        parse_self: attributes[:parse_self],
        shard_id: attributes[:shard_id],
        num_shards: attributes[:num_shards],
        redact_token: attributes.key?(:redact_token) ? attributes[:redact_token] : true,
        ignore_bots: attributes[:ignore_bots],
        compress_mode: attributes[:compress_mode],
        intents: attributes[:intents] || :all
      )

      @prefix = attributes[:prefix]

      # Validate single-codepoint delimiters
      %i[previous chain_delimiter chain_args_delim sub_chain_start sub_chain_end quote_start quote_end].each do |key|
        val = attributes.fetch(key) { DEFAULT_DELIMITERS[key] }
        next if val.nil? || val.is_a?(FalseClass) || val.empty?
        next if val.length == 1 || val.length == val.codepoints.length

        raise ArgumentError, "#{key} must be a single codepoint, got #{val.inspect}"
      end

      @attributes = {
        advanced_functionality: attributes.fetch(:advanced_functionality, false),
        help_command: attributes[:help_command].is_a?(FalseClass) ? nil : (attributes.fetch(:help_command, :help)),
        command_doesnt_exist_message: attributes[:command_doesnt_exist_message],
        no_permission_message: attributes[:no_permission_message],
        spaces_allowed: attributes.fetch(:spaces_allowed, false),
        webhook_commands: attributes.fetch(:webhook_commands, true),
        channels: Array(attributes[:channels]),

        # All of the following need to be one character
        previous: attributes.fetch(:previous, DEFAULT_DELIMITERS[:previous]),
        chain_delimiter: attributes.fetch(:chain_delimiter, DEFAULT_DELIMITERS[:chain_delimiter]),
        chain_args_delim: attributes.fetch(:chain_args_delim, DEFAULT_DELIMITERS[:chain_args_delim]),
        sub_chain_start: attributes.fetch(:sub_chain_start, DEFAULT_DELIMITERS[:sub_chain_start]),
        sub_chain_end: attributes.fetch(:sub_chain_end, DEFAULT_DELIMITERS[:sub_chain_end]),
        quote_start: attributes.fetch(:quote_start, DEFAULT_DELIMITERS[:quote_start]),
        quote_end: attributes.fetch(:quote_end, attributes[:quote_start] || DEFAULT_DELIMITERS[:quote_end]),

        rescue: attributes[:rescue],

        # Execution budget limits (DoS protection)
        max_chain_repeat: attributes.fetch(:max_chain_repeat, 25),
        max_subchain_depth: attributes.fetch(:max_subchain_depth, 16),
        max_chain_commands: attributes.fetch(:max_chain_commands, 50),
        max_expanded_executions: attributes.fetch(:max_expanded_executions, 100),
        max_chain_duration: attributes.fetch(:max_chain_duration, 10),
        max_command_duration: attributes.fetch(:max_command_duration, 5),
        max_chain_output_bytes: attributes.fetch(:max_chain_output_bytes, 64 * 1024),
        max_chain_input_bytes: attributes.fetch(:max_chain_input_bytes, 16 * 1024),
        max_message_output_chars: attributes.fetch(:max_message_output_chars, 2_000)
      }

      @permissions = {
        roles: {},
        users: {}
      }

      return unless @attributes[:help_command]

      command(@attributes[:help_command], max_args: 1, description: 'Shows a list of all the commands available or displays help for a specific command.', usage: 'help [command name]') do |event, command_name|
        if command_name
          command = resolve_command(command_name.to_sym)
          # rubocop:disable Lint/ReturnInVoidContext
          return "The command `#{command_name}` does not exist!" unless command
          # rubocop:enable Lint/ReturnInVoidContext

          desc = command.attributes[:description] || '*No description available*'
          usage = command.attributes[:usage]
          parameters = command.attributes[:parameters]
          result = String.new("**`#{command.name}`**: #{desc}")
          aliases = command_aliases(command.name)
          unless aliases.empty?
            result << "\nAliases: "
            result << aliases.map { |a| "`#{a.name}`" }.join(', ')
          end
          result << "\nUsage: `#{usage}`" if usage
          if parameters
            result << "\nAccepted Parameters:\n```"
            parameters.each { |p| result << "\n#{p}" }
            result << '```'
          end
          paginate_text(result, @attributes[:max_message_output_chars] || 2_000)
        else
          available_commands = @commands.values.reject do |c|
            c.is_a?(CommandAlias) || !c.attributes[:help_available] || !required_roles?(event.user, c.attributes[:required_roles]) || !allowed_roles?(event.user, c.attributes[:allowed_roles]) || !required_permissions?(event.user, c.attributes[:required_permissions], event.channel)
          end
          case available_commands.length
          when 0..5
            buf = String.new("**List of commands:**\n")
            available_commands.each { |c| buf << "**`#{c.name}`**: #{c.attributes[:description] || '*No description available*'}\n" }
            buf
          when 6..50
            buf = String.new("**List of commands:**\n")
            available_commands.each { |c| buf << "`#{c.name}`, " }
            buf[0..-3]
          else
            buf = String.new("**List of commands:**\n")
            available_commands.each { |c| buf << "`#{c.name}`, " }
            event.user.pm(buf[0..-3])
            event.channel.pm? ? '' : 'Sending list in PM!'
          end
        end
      end
    end

    private

    # Splits text into chunks that fit within Discord's character limit,
    # breaking at newlines to avoid splitting code blocks.
    # @param text [String] The text to paginate.
    # @param max_chars [Integer] Maximum characters per page.
    # @return [String] The text if it fits, or the first page.
    def paginate_text(text, max_chars = 2_000)
      return text if text.bytesize <= max_chars

      pages = []
      current = String.new
      text.each_line do |line|
        if current.bytesize + line.bytesize > max_chars
          pages << current
          current = String.new
        end
        current << line
      end
      pages << current unless current.empty?
      pages.first || text[0...max_chars]
    end
  end
end
