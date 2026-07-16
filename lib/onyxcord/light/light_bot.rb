# frozen_string_literal: true

require 'onyxcord/rest/client'
require 'onyxcord/rest/routes/user'
require 'onyxcord/light/credential'
require 'onyxcord/light/data'
require 'onyxcord/light/integrations'

# This module contains classes to allow connections to bots without a connection to the gateway socket, i.e. bots
# that only use the REST part of the API.
module OnyxCord::Light
  # A lightweight client that only uses the REST part of the API. Hierarchically unrelated to the regular
  # {OnyxCord::Bot}. Useful to make applications integrated to Discord over OAuth, for example.
  #
  # {LightBot} supports two kinds of credentials:
  # - bot tokens (`token_type: :bot`) for the application's own REST surface; and
  # - OAuth2 Bearer access tokens (`token_type: :bearer`) for user-installed OAuth2 applications.
  #
  # Raw user account tokens are rejected (see {UserTokenRejected}). Automating normal user accounts (self-bots) is
  # forbidden by Discord and may get the underlying account disabled.
  class LightBot
    # @return [Credential] the credential used to authenticate. Never exposes the raw token.
    attr_reader :credential

    # OAuth2 scopes required by each public operation, keyed by method name.
    REQUIRED_SCOPES = {
      profile: %i[identify],
      servers: %i[guilds],
      connections: %i[connections]
    }.freeze

    # Create a new LightBot. This does no networking yet; all networking is done by the methods on this class.
    #
    # @param token [String, #token] the bot token, OAuth2 Bearer access token, or an OAuth2 token object that
    #   responds to `#token` (and optionally `#scope`). A raw user account token is rejected with
    #   {UserTokenRejected}.
    # @param token_type [Symbol, nil] `:bot` for a bot token or `:bearer` for an OAuth2 Bearer access token.
    #   Required for unprefixed tokens; when omitted, prefixed values (`Bot ...`, `Bearer ...`) are accepted.
    # @param scopes [Array<Symbol>, String, nil] OAuth2 scopes granted to `token`, when known. When set, {LightBot}
    #   raises {MissingScopeError} before issuing a request that needs a scope that is missing. When nil the
    #   scope check is skipped and the request is issued normally.
    # @example Bot token
    #   bot = OnyxCord::Light::LightBot.new(ENV.fetch('BOT_TOKEN'), token_type: :bot)
    # @example OAuth2 Bearer token with scopes
    #   bot = OnyxCord::Light::LightBot.new(access_token,
    #                                       token_type: :bearer,
    #                                       scopes: %i[identify guilds connections])
    def initialize(token, token_type: nil, scopes: nil)
      @credential = Credential.for(token, token_type: token_type, scopes: scopes)
    end

    # @return [LightProfile] the details of the user this bot is connected to.
    # @raise [MissingScopeError] when the credential declares a scope list that does not include `:identify`.
    def profile
      credential.require_scope!(:identify)
      LightProfile.new(request_profile_json, self)
    end

    # @return [Array<LightServer>] the servers this bot is connected to.
    # @raise [MissingScopeError] when the credential declares a scope list that does not include `:guilds`.
    def servers
      credential.require_scope!(:guilds)
      payload = request_servers_json
      payload.map { |entry| LightServer.new(entry, self) }.freeze
    end

    # Gets the connections associated with this account.
    # @return [Array<Connection>] this account's connections.
    # @raise [MissingScopeError] when the credential declares a scope list that does not include `:connections`.
    def connections
      credential.require_scope!(:connections)
      payload = request_connections_json
      payload.map { |entry| Connection.new(entry, self) }.freeze
    end

    # Builds the OAuth2 authorization URL that should be used to add the bot to a guild. Replaces the previous
    # `#join` method which called `POST /invites/{code}`; bots must be installed through OAuth2, not by accepting
    # invite codes.
    # @param client_id [Integer, String] the bot's application client ID.
    # @param permissions [Integer, nil] the bitwise permission integer to request. Defaults to 0 (no permissions).
    # @param guild_id [Integer, String, nil] when set, opens the OAuth2 flow already targeting a specific guild.
    # @param scope [Array<String>, String, nil] OAuth2 scopes. Defaults to `['bot']`.
    # @param redirect_uri [String, nil] optional redirect URI.
    # @return [String] the authorization URL.
    def self.oauth_authorize_url(client_id, permissions: nil, guild_id: nil, scope: ['bot'], redirect_uri: nil)
      scopes = scope.is_a?(Array) ? scope.join(' ') : scope.to_s
      params = {
        client_id: client_id,
        scope: scopes
      }
      params[:permissions] = permissions if permissions
      params[:guild_id] = guild_id if guild_id
      params[:redirect_uri] = redirect_uri if redirect_uri
      params[:response_type] = 'code'
      query = params.map { |k, v| "#{k}=#{URI.encode_www_form_component(v)}" }.join('&')
      "https://discord.com/api/oauth2/authorize?#{query}"
    end

    # Overridden to never leak the credential's raw token.
    # @return [String] a redacted inspect string.
    def inspect
      "#<#{self.class.name} credential=#{credential.inspect}>"
    end

    # @!visibility private
    # Helper for tests and internal callers. Returns the raw Authorization header value; never log this.
    def _authorization
      credential.authorization
    end

    private

    REQUIRED_SCOPES.each do |method, scopes|
      scoped_method = method
      define_method(:"require_scopes_for_#{method}!") do
        scopes.each { |s| credential.require_scope!(s) }
      end
      private(:"require_scopes_for_#{method}!")
    end

    def request_profile_json
      JSON.parse(OnyxCord::REST::User.profile(credential.authorization))
    end

    def request_servers_json
      JSON.parse(OnyxCord::REST::User.servers(credential.authorization))
    end

    def request_connections_json
      JSON.parse(OnyxCord::REST::User.connections(credential.authorization))
    end
  end
end
