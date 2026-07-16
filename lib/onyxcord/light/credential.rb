# frozen_string_literal: true

module OnyxCord::Light
  # Error raised when a raw user account token is passed to {LightBot}.
  # Discord forbids automating normal user accounts (self-bots); only bot tokens
  # and OAuth2 Bearer tokens are supported by the Light API.
  class UserTokenRejected < ArgumentError
    def initialize(msg = nil)
      super(msg || 'Raw user account tokens are not accepted. ' \
                   'Pass a bot token with token_type: :bot or an OAuth2 Bearer ' \
                   'token with token_type: :bearer. Automating normal user ' \
                   'accounts is forbidden by Discord and may get your account disabled.')
    end
  end

  # Error raised when a required OAuth2 scope is missing from the credential.
  class MissingScopeError < StandardError
    # @return [Symbol] the scope name that was required.
    attr_reader :scope

    # @return [Array<Symbol>, nil] the scopes actually present on the credential, if known.
    attr_reader :present_scopes

    def initialize(scope, present_scopes: nil)
      @scope = scope
      @present_scopes = present_scopes
      have = present_scopes ? present_scopes.inspect : 'unknown'
      super("Missing required OAuth2 scope :#{scope} (present: #{have}). " \
            'Grant the scope in your authorization URL and retry.')
    end
  end

  # Internal credential object that builds the Authorization header for Discord
  # REST requests. It is polymorphic on the token type and never exposes the raw
  # token value through {#to_s}, {#inspect} or {#pretty_print} so credentials
  # are not leaked into logs, error backtraces or consoles.
  #
  # {Credential.for} is the factory used by {LightBot}; prefer going through
  # {LightBot#initialize} instead of picking a subclass directly.
  class Credential
    # @return [String, nil] the OAuth2 scopes declared on this credential, as a
    #   space-separated string or nil when not known.
    attr_reader :scopes

    # Factory that converts the arguments accepted by {LightBot.new} into the
    # correct {Credential} subclass. It rejects raw user account tokens and
    # normalises already-prefixed tokens and OAuth2 token objects.
    #
    # @param token [String, #token] the raw token, an OAuth2 token object that
    #   responds to `#token`, or nil.
    # @param token_type [Symbol, nil] one of :bot, :bearer. When nil the type is
    #   inferred only when the token is already prefixed (Bot .../Bearer ...);
    #   an unprefixed token without :token_type is rejected as ambiguous to
    #   avoid the heuristic of counting dots.
    # @param scopes [Array<Symbol>, String, nil] OAuth2 scopes available on the
    #   token, when known by the caller. Used by {LightBot} to raise
    #   {MissingScopeError} before issuing a request.
    # @return [Credential]
    def self.for(token, token_type: nil, scopes: nil)
      if token.respond_to?(:token)
        scopes ||= token.respond_to?(:scope) ? token.scope : nil
        token = token.token
      end

      token = token.to_s unless token.nil?

      if token.nil? || token.empty?
        raise ArgumentError, 'token must not be nil or empty'
      end

      if token_type.nil?
        if token.start_with?('Bot ')
          token_type = :bot
          token = token.sub(/\ABot\s+/, '')
        elsif token.start_with?('Bearer ')
          token_type = :bearer
          token = token.sub(/\ABearer\s+/, '')
        else
          raise UserTokenRejected,
                'Unprefixed token without token_type:. ' \
                'Pass token_type: :bot for a bot token or token_type: :bearer ' \
                'for an OAuth2 Bearer token. Discord forbids automating normal ' \
                'user accounts (self-bots).'
        end
      else
        token_type = token_type.to_sym
        unless %i[bot bearer].include?(token_type)
          raise ArgumentError, "invalid token_type #{token_type.inspect}; " \
                               'expected :bot or :bearer'
        end
        token = token.sub(/\A(?:Bot|Bearer)\s+/, '')
      end

      klass = token_type == :bot ? BotCredential : BearerCredential
      klass.new(token, scopes: normalize_scopes(scopes))
    end

    # Normalizes a scope declaration to a frozen Array of Symbols.
    # @param scopes [Array, String, nil] a scope array, a space-separated
    #   OAuth2 scope string, or nil when scopes are unknown.
    # @return [Array<Symbol>, nil]
    def self.normalize_scopes(scopes)
      return nil if scopes.nil?

      case scopes
      when Array
        scopes.map(&:to_sym)
      when String
        scopes.split(/\s+/).map(&:to_sym)
      else
        Array(scopes).map(&:to_sym)
      end
    end

    # @!visibility private
    def initialize(token, scopes: nil)
      @token = token.to_s
      @scopes = self.class.normalize_scopes(scopes)&.freeze
    end

    # @return [String] the value to send as the HTTP Authorization header,
    #   including the scheme (e.g. "Bot ..." or "Bearer ...").
    def authorization
      raise NotImplementedError
    end

    # @return [:bot, :bearer] the credential kind.
    def type
      raise NotImplementedError
    end

    # True when the declared scopes (if any) include `name`.
    def has_scope?(name)
      return true if @scopes.nil?

      @scopes.include?(name.to_sym)
    end

    # Raises {MissingScopeError} when the credential declares a scope list and
    # `name` is not in it. When scopes are unknown the check is skipped so we
    # never block a caller that did not supply scope metadata.
    def require_scope!(name)
      return if @scopes.nil?

      return if @scopes.include?(name.to_sym)

      raise MissingScopeError.new(name.to_sym, present_scopes: @scopes)
    end

    # Overridden by subclasses to return `false` for Bearer credentials that
    # cannot reach bot-only endpoints. Used by {LightBot} to raise early.
    def supports?
      true
    end

    # Never exposes the token value. Returns a redacted placeholder.
    def to_s
      '[redacted credential]'
    end

    alias_method :inspect, :to_s

    def pretty_print(q)
      q.text(to_s)
    end

    private

    def self.normalize_scopes(scopes)
      return nil if scopes.nil?

      case scopes
      when Array
        scopes.map(&:to_sym)
      when String
        scopes.split(/\s+/).map(&:to_sym)
      else
        Array(scopes).map(&:to_sym)
      end
    end

    protected

    def raw_token
      @token
    end
  end

  # Credential for a Discord bot token. Sends `Authorization: Bot <token>`.
  class BotCredential < Credential
    def authorization
      "Bot #{@token}"
    end

    def type
      :bot
    end
  end

  # Credential for an OAuth2 Bearer access token. Sends
  # `Authorization: Bearer <token>`. Bearer tokens drive the user-oriented
  # OAuth2 endpoints (`/users/@me`, `/users/@me/guilds`, `/users/@me/connections`)
  # and should carry scope metadata whenever the caller knows it.
  class BearerCredential < Credential
    def authorization
      "Bearer #{@token}"
    end

    def type
      :bearer
    end

    # Bearer credentials target the user OAuth2 surface and have no access to
    # bot-only endpoints. {LightBot} uses this to reject unsupported operations
    # up-front instead of letting the API return 401.
    def supports?(*)
      false
    end
  end

  # Expose normalize_scopes as a module function for use by specs and other
  # callers without going through the factory.
  class << Credential
    public :normalize_scopes
  end
end
