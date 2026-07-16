# frozen_string_literal: true

require 'onyxcord/light/data'

module OnyxCord::Light
  # Lightweight account data for a connection integration. Only `id`, `name`
  # and `type`. Replaces the previous practice of wrapping account data inside a
  # full {Connection} object (which allocated a restructured Hash and a bogus
  # Connection with empty integrations).
  class IntegrationAccount
    # @return [String] the account ID on the external service.
    attr_reader :id

    # @return [String] the account name on the external service.
    attr_reader :name

    # @return [String] the connection type name (e.g. "twitch", "youtube").
    attr_reader :type

    # @param data [Hash] the raw `account` sub-object from the integration payload.
    def initialize(data)
      @id = data['id']
      @name = data['name']
      @type = data['type']
    end

    def to_s
      "#<IntegrationAccount #{@type.inspect} name=#{@name.inspect} id=#{@id.inspect}>"
    end

    alias_method :inspect, :to_s
  end

  # Known connection types as frozen Strings mapped to Symbols. Used for
  # optional lookup; types not in this map are preserved as Strings without
  # allocating any Symbol.
  KNOWN_CONNECTION_TYPES = {
    'twitch' => :twitch,
    'youtube' => :youtube,
    'github' => :github,
    'steam' => :steam,
    'spotify' => :spotify,
    'reddit' => :reddit,
    'xbox' => :xbox,
    'tiktok' => :tiktok,
    'epic' => :epic,
    'facebook' => :facebook,
    'twitter' => :twitter,
    'leagueoflegends' => :leagueoflegends,
    'battlenet' => :battlenet,
    'ebay' => :ebay,
    'paypal' => :paypal,
    'instagram' => :instagram,
    'domain' => :domain
  }.freeze

  # Mapa inverso para conversão (Symbol → String).
  KNOWN_CONNECTION_TYPE_NAMES = KNOWN_CONNECTION_TYPES.to_h { |k, v| [v, k] }.freeze

  # A connection of your Discord account to a particular other service (e.g.
  # Twitch, YouTube, GitHub, Steam, etc.).
  class Connection
    # @return [String] the connection type name (frozen String, e.g. "twitch").
    attr_reader :type

    # The same value as {#type}, but converted to a Symbol when the type is in
    # {KNOWN_CONNECTION_TYPES}. Unknown types return `nil` — always use {#type}
    # (the String) for round-trip fidelity.
    # @return [Symbol, nil]
    def type_sym
      KNOWN_CONNECTION_TYPES[@type]
    end

    alias_method :type_symbol, :type_sym

    # @return [true, false, nil] whether this connection is revoked.
    #   `nil` means the information is not present in the payload (unknown).
    def revoked
      @revoked
    end

    alias_method :revoked?, :revoked

    # @return [String] the name of the connected account.
    attr_reader :name

    # @return [String] the ID of the connected account.
    attr_reader :id

    # @return [true, false, nil] whether the connection is verified.
    def verified
      @verified
    end

    alias_method :verified?, :verified

    # @return [true, false, nil] whether friend sync is enabled for this connection.
    def friend_sync
      @friend_sync
    end

    alias_method :friend_sync?, :friend_sync

    # @return [true, false, nil] whether the activity is shown on the profile.
    def show_activity
      @show_activity
    end

    alias_method :show_activity?, :show_activity

    # @return [true, false, nil] whether this connection has a two-way link.
    def two_way_link
      @two_way_link
    end

    alias_method :two_way_link?, :two_way_link

    # @return [Integer, nil] visibility setting (0=none, 1=everyone).
    def visibility
      @visibility
    end

    # @return [Array<Integration>] the integrations for this connection. Empty
    #   frozen array when absent (integrations is an optional field).
    attr_reader :integrations

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @revoked = data['revoked']
      @type = data['type'].to_s.freeze
      @name = data['name']
      @id = data['id']
      @verified = data['verified']
      @friend_sync = data['friend_sync']
      @show_activity = data['show_activity']
      @two_way_link = data['two_way_link']
      @visibility = data['visibility']

      raw_integrations = Array(data['integrations'])
      if raw_integrations.empty?
        @integrations = [].freeze
      else
        @integrations = raw_integrations.map { |e| Integration.new(e, self, bot) }.freeze
      end
    end

    def inspect
      "#<#{self.class.name} type=#{@type.inspect} name=#{@name.inspect}>"
    end
  end

  # An integration of a connection into a particular server, for example being
  # a member of a subscriber-only Twitch server.
  class Integration
    # @return [UltraLightServer] the server associated with this integration.
    attr_reader :server

    # @return [IntegrationAccount] the underlying account tied to the server's
    #   connection (e.g. the Twitch account of the server owner). Replaces the
    #   previous {#server_connection} which allocated a full {Connection}
    #   wrapping restructured data.
    attr_reader :server_account

    alias_method :server_connection, :server_account

    # @return [String] the ID of the integrated connection (i.e. your
    #   connection ID). Keeps only the ID to avoid retaining the full
    #   Connection graph.
    def integrated_connection_id
      @integrated_connection_id
    end

    # @param data [Hash] the raw integration payload.
    # @param integrated [Connection] the parent connection (for reference during construction only).
    # @param bot [LightBot] the owning client.
    # @!visibility private
    def initialize(data, integrated, bot)
      @bot = bot
      @integrated_connection_id = integrated.id

      id_raw = data['id']
      raise ArgumentError, "Missing 'id' in Integration payload" unless id_raw

      @id = id_raw.to_i
      @data = data

      guild_data = data['guild']
      if guild_data && !guild_data.empty?
        @server = UltraLightServer.new(guild_data, bot)
      end

      account_data = data['account'] || {}
      @server_account = IntegrationAccount.new(account_data)
    end

    # @return [Integer] the ID which uniquely identifies this integration.
    define_method(:id) { @id }
    alias_method :resolve_id, :id

    def inspect
      "<Integration id=#{id}>"
    end
  end
end