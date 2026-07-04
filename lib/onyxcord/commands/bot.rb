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
      # TODO: This needs to be revisited. undefined attributes are treated
      # as explicitly passed nils.
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
      @attributes = {
        # Whether advanced functionality such as command chains are enabled
        advanced_functionality: attributes[:advanced_functionality].nil? ? false : attributes[:advanced_functionality],

        # The name of the help command (that displays information to other commands). False if none should exist
        help_command: attributes[:help_command].is_a?(FalseClass) ? nil : (attributes[:help_command] || :help),

        # The message to display for when a command doesn't exist, %command% to get the command name in question and nil for no message
        # No default value here because it may not be desired behaviour
        command_doesnt_exist_message: attributes[:command_doesnt_exist_message],

        # The message to be displayed when `NoPermission` error is raised.
        no_permission_message: attributes[:no_permission_message],

        # Spaces allowed between prefix and command
        spaces_allowed: attributes[:spaces_allowed].nil? ? false : attributes[:spaces_allowed],

        # Webhooks allowed to trigger commands
        webhook_commands: attributes[:webhook_commands].nil? || attributes[:webhook_commands],

        channels: attributes[:channels] || [],

        # All of the following need to be one character
        # String to designate previous result in command chain
        previous: attributes[:previous] || '~',

        # Command chain delimiter
        chain_delimiter: attributes[:chain_delimiter] || '>',

        # Chain argument delimiter
        chain_args_delim: attributes[:chain_args_delim] || ':',

        # Sub-chain starting character
        sub_chain_start: attributes[:sub_chain_start] || '[',

        # Sub-chain ending character
        sub_chain_end: attributes[:sub_chain_end] || ']',

        # Quoted mode starting character
        quote_start: attributes[:quote_start] || '"',

        # Quoted mode ending character
        quote_end: attributes[:quote_end] || attributes[:quote_start] || '"',

        # Default block for handling internal exceptions, or a string to respond with
        rescue: attributes[:rescue]
      }

      @permissions = {
        roles: {},
        users: {}
      }

      return unless @attributes[:help_command]

      command(@attributes[:help_command], max_args: 1, description: 'Shows a list of all the commands available or displays help for a specific command.', usage: 'help [command name]') do |event, command_name|
        if command_name
          command = @commands[command_name.to_sym]
          if command.is_a?(CommandAlias)
            command = command.aliased_command
            command_name = command.name
          end
          # rubocop:disable Lint/ReturnInVoidContext
          return "The command `#{command_name}` does not exist!" unless command
          # rubocop:enable Lint/ReturnInVoidContext

          desc = command.attributes[:description] || '*No description available*'
          usage = command.attributes[:usage]
          parameters = command.attributes[:parameters]
          result = "**`#{command_name}`**: #{desc}"
          aliases = command_aliases(command_name.to_sym)
          unless aliases.empty?
            result += "\nAliases: "
            result += aliases.map { |a| "`#{a.name}`" }.join(', ')
          end
          result += "\nUsage: `#{usage}`" if usage
          if parameters
            result += "\nAccepted Parameters:\n```"
            parameters.each { |p| result += "\n#{p}" }
            result += '```'
          end
          result
        else
          available_commands = @commands.values.reject do |c|
            c.is_a?(CommandAlias) || !c.attributes[:help_available] || !required_roles?(event.user, c.attributes[:required_roles]) || !allowed_roles?(event.user, c.attributes[:allowed_roles]) || !required_permissions?(event.user, c.attributes[:required_permissions], event.channel)
          end
          case available_commands.length
          when 0..5
            available_commands.reduce "**List of commands:**\n" do |memo, c|
              memo + "**`#{c.name}`**: #{c.attributes[:description] || '*No description available*'}\n"
            end
          when 5..50
            (available_commands.reduce "**List of commands:**\n" do |memo, c|
              memo + "`#{c.name}`, "
            end)[0..-3]
          else
            event.user.pm(available_commands.reduce("**List of commands:**\n") { |m, e| m + "`#{e.name}`, " }[0..-3])
            event.channel.pm? ? '' : 'Sending list in PM!'
          end
        end
      end
    end

    # Returns all aliases for the command with the given name
    # @param name [Symbol] the name of the `Command`
    # @return [Array<CommandAlias>]
  end
end
