# frozen_string_literal: true

require 'zlib'
require_relative 'core/bot/runtime'
require_relative 'core/bot/invites'
require_relative 'core/bot/voice'
require_relative 'core/bot/messaging'
require_relative 'core/bot/oauth'
require_relative 'core/bot/presence'
require_relative 'core/bot/awaits'
require_relative 'core/bot/application_commands'

module OnyxCord
  # Represents a Discord bot, including servers, users, etc.
  class Bot
    # The list of currently running threads used to parse and call events.
    # The threads will have a local variable `:onyxcord_name` in the format of `et-1234`, where
    # "et" stands for "event thread" and the number is a continually incrementing number representing
    # how many events were executed before.
    # @return [Array<Thread>] The threads.
    attr_reader :event_threads

    # @return [true, false] whether or not the bot should parse its own messages. Off by default.
    attr_accessor :should_parse_self

    # The bot's name which onyxcord sends to Discord when making any request, so Discord can identify bots with the
    # same codebase. Not required but I recommend setting it anyway.
    # @return [String] The bot's name.
    attr_accessor :name

    # @return [Array(Integer, Integer)] the current shard key
    attr_reader :shard_key

    # @return [Hash<Symbol => Await>] the list of registered {Await}s.
    attr_reader :awaits

    # The gateway connection is an internal detail that is useless to most people. It is however essential while
    # debugging or developing onyxcord itself, or while writing very custom bots.
    # @return [Gateway] the underlying {Gateway} object.
    attr_reader :gateway

    # @return [:raw, :hybrid, :object] the dispatch mode used by this bot.
    attr_reader :mode

    # @return [Hash] the normalized cache policy for this bot.
    attr_reader :cache_policy

    # @return [Internal::EventExecutor::Inline, Internal::EventExecutor::Pool, Internal::EventExecutor::AsyncPool]
    attr_reader :event_executor

    # @return [Logger] the per-bot logger instance.
    attr_reader :logger

    include EventContainer
    include Cache
    include Internal::EventBus
    include Runtime
    include Invites
    include VoiceControl
    include Messaging
    include OAuth
    include Presence
    include Awaits
    include ApplicationCommands

    # Makes a new bot with the given authentication data. It will be ready to be added event handlers to and can
    # eventually be run with {#run}.
    #
    # As support for logging in using username and password has been removed in version 3.0.0, only a token login is
    # possible. Be sure to specify the `type` parameter as `:user` if you're logging in as a user.
    #
    # Simply creating a bot won't be enough to start sending messages etc. with, only a limited set of methods can
    # be used after logging in. If you want to do something when the bot has connected successfully, either do it in the
    # {#ready} event, or use the {#run} method with the :async parameter and do the processing after that.
    # @param log_mode [Symbol] The mode this bot should use for logging. See {Logger#mode=} for a list of modes.
    # @param token [String] The token that should be used to log in. If your bot is a bot account, you have to specify
    #   this. If you're logging in as a user, make sure to also set the account type to :user so onyxcord doesn't think
    #   you're trying to log in as a bot.
    # @param client_id [Integer] If you're logging in as a bot, the bot's client ID. This is optional, and may be fetched
    #   from the API by calling {Bot#bot_application} (see {Application}).
    # @param type [Symbol] This parameter lets you manually overwrite the account type. This needs to be set when
    #   logging in as a user, otherwise onyxcord will treat you as a bot account. Valid values are `:user` and `:bot`.
    # @param name [String] Your bot's name. This will be sent to Discord with any API requests, who will use this to
    #   trace the source of excessive API requests; it's recommended to set this to something if you make bots that many
    #   people will host on their servers separately.
    # @param fancy_log [true, false] Whether the output log should be made extra fancy using ANSI escape codes. (Your
    #   terminal may not support this.)
    # @param suppress_ready [true, false] Whether the READY packet should be exempt from being printed to console.
    #   Useful for very large bots running in debug or verbose log_mode.
    # @param parse_self [true, false] Whether the bot should react on its own messages. It's best to turn this off
    #   unless you really need this so you don't inadvertently create infinite loops.
    # @param shard_id [Integer] The number of the shard this bot should handle. See
    #   https://github.com/discord/discord-api-docs/issues/17 for how to do sharding.
    # @param num_shards [Integer] The total number of shards that should be running. See
    #   https://github.com/discord/discord-api-docs/issues/17 for how to do sharding.
    # @param redact_token [true, false] Whether the bot should redact the token in logs. Default is true.
    # @param ignore_bots [true, false] Whether the bot should ignore bot accounts or not. Default is false.
    # @param compress_mode [:none, :large, :stream] Sets which compression mode should be used when connecting
    #   to Discord's gateway. `:none` will request that no payloads are received compressed (not recommended for
    #   production bots). `:large` will request that large payloads are received compressed. `:stream` will request
    #   that all data be received in a continuous compressed stream.
    # @param intents [:all, :unprivileged, Array<Symbol>, :none, Integer] Gateway intents that this bot requires. `:all` will
    #   request all intents. `:unprivileged` will request only intents that are not defined as "Privileged". `:none`
    #   will request no intents. An array of symbols will request only those intents specified. An integer value will request
    #   exactly all the intents specified in the bitwise value.
    # @see OnyxCord::INTENTS
    def initialize(
      log_mode: :normal,
      token: nil, client_id: nil,
      type: nil, name: '', fancy_log: false, suppress_ready: false, parse_self: false,
      shard_id: nil, num_shards: nil, redact_token: true, ignore_bots: false,
      compress_mode: :large, intents: :minimal,
      mode: nil, cache: nil, event_executor: nil, event_workers: nil, event_queue_size: nil
    )
      config = OnyxCord.configuration
      @mode = config.normalize_mode(mode)
      @cache_policy = config.normalize_cache(cache)
      executor_type = config.normalize_event_executor(event_executor)
      executor_workers = config.normalize_event_workers(event_workers)
      executor_queue_size = config.normalize_event_queue_size(event_queue_size)

      @logger = OnyxCord::Logger.new(fancy_log)
      @logger.mode = log_mode
      @logger.token = token if redact_token

      @should_parse_self = parse_self

      @client_id = client_id

      @type = type || :bot
      @name = name
      @redact_token = redact_token
      REST.bot_name = @name

      @shard_key = if num_shards
        raise ArgumentError, "shard_id must be provided when num_shards is given" unless shard_id
        raise ArgumentError, "shard_id must be between 0 and num_shards - 1" unless shard_id.between?(0, num_shards - 1)

        [shard_id, num_shards]
      end

      @logger.fancy = fancy_log
      @prevent_ready = suppress_ready

      @compress_mode = compress_mode

      raise 'Token string is empty or nil' if token.nil? || token.empty?

      @intents = case intents
                 when :all
                   ALL_INTENTS
                 when :unprivileged
                   UNPRIVILEGED_INTENTS
                 when :minimal
                   MINIMAL_INTENTS
                 when :none
                   NO_INTENTS
                 else
                   calculate_intents(intents)
                 end

      @token = process_token(@type, token)
      @gateway = Gateway::Client.new(self, @token, @shard_key, @compress_mode, @intents)

      init_cache

      @voices = {}
      @voices_mutex = Mutex.new
      @should_connect_to_voice = {}
      @should_connect_voice_mutex = Mutex.new
      @session_id = nil
      @session_id_mutex = Mutex.new

      @ignored_ids = Set.new
      @ignore_bots = ignore_bots

      @current_thread = 0
      @current_thread_mutex = Mutex.new
      @event_executor = Internal::EventExecutor.build(executor_type, workers: executor_workers, queue_size: executor_queue_size)
      @event_threads = @event_executor.threads

      @status = :online

      @application_commands = {}
    end

    # The list of users the bot shares a server with.
    # @return [Hash<Integer => User>] The users by ID.
    def users
      gateway_check
      unavailable_servers_check
      @users
    end

    # The list of servers the bot is currently in.
    # @return [Hash<Integer => Server>] The servers by ID.
    def servers
      gateway_check
      unavailable_servers_check
      @servers
    end

    # The list of members in threads the bot can see.
    # @return [Hash<Integer => Hash<Integer => Hash<String => Object>>]
    def thread_members
      gateway_check
      unavailable_servers_check
      @thread_members
    end

    # @overload emoji(id)
    #   Return an emoji by its ID
    #   @param id [String, Integer] The emoji's ID.
    #   @return [Emoji, nil] the emoji object. `nil` if the emoji was not found.
    # @overload emoji
    #   The list of emoji the bot can use.
    #   @return [Array<Emoji>] the emoji available.
    def emoji(id = nil)
      if (id = id&.resolve_id)
        @servers&.each_value do |server|
          emoji = server.emojis[id]
          return emoji if emoji
        end
        nil
      else
        hash = {}
        @servers&.each_value { |server| hash.merge!(server.emojis) }
        hash
      end
    end

    alias_method :emojis, :emoji
    alias_method :all_emoji, :emoji

    # Finds an emoji by its name.
    # @param name [String] The emoji name that should be resolved.
    # @return [GlobalEmoji, nil] the emoji identified by the name, or `nil` if it couldn't be found.
    def find_emoji(name)
      @logger.out("Resolving emoji #{name}")
      emoji.find { |element| element.name == name }
    end

    # The bot's user profile. This special user object can be used
    # to edit user data like the current username (see {Profile#username=}).
    # @return [Profile] The bot's profile that can be used to edit data.
    def profile
      return @profile if @profile

      response = OnyxCord::REST::User.profile(@token)
      @profile = Profile.new(JSON.parse(response), self)
    end

    alias_method :bot_user, :profile

    # The bot's OAuth application.
    # @return [Application] The bot's application info.
    def bot_application
      response = REST.current_application(token)
      Application.new(OnyxCord::Internal::JSON.parse(response), self)
    end

    alias_method :bot_app, :bot_application
    alias_method :application, :bot_application

    # Resolve (and cache) the application ID associated with this bot.
    # @return [Integer] The application ID.
    #   Uses `@client_id` when explicitly informed during construction or
    #   resolved from the READY payload; otherwise fetches via `GET /applications/@me`.
    def application_id
      @client_id ||= bot_application.id
    end

    # Get the role connection metadata records associated with this application.
    # @return [Array<RoleConnectionMetadata>] the role connection metadata records associated with this application.
    # @raise [RuntimeError] if the application ID cannot be determined.
    def role_connection_metadata_records
      response = REST::Application.get_application_role_connection_metadata_records(token, application_id)
      OnyxCord::Internal::JSON.parse(response).map { |role_connection| RoleConnectionMetadata.new(role_connection, self) }
    end

    # The Discord API token received when logging in. Useful to explicitly call
    # {API} methods.
    # @return [String] The API token.
    def token
      @token
    end

    # @return [String] the raw token, without any prefix
    # @see #token
    def raw_token
      @token.split(' ').last
    end

    # @!visibility private
    # @deprecated Use {application_id} instead — this method is kept
    #   only for backward compatibility and will delegate.
    def resolve_application_id!
      application_id
      @client_id
    end

    # @!visibility private
    def inspect
      "<Bot client_id=#{@client_id.inspect} redact_token=#{@redact_token.inspect}>"
    end
  end
end
