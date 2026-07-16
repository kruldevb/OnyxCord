# frozen_string_literal: true

require 'onyxcord/utils/id_object'

module OnyxCord
  # Builder class for `allowed mentions` when sending messages.
  class AllowedMentions
    # The maximum number of explicit IDs the API accepts for users or roles.
    MAX_IDS = 100

    # Allowed values for the `parse` array.
    PARSE_TYPES = %w[users roles everyone].freeze

    # Snowflake pattern: 17-19 digit positive integer.
    SNOWFLAKE_PATTERN = /\A\d{17,19}\z/.freeze

    class Error < ArgumentError; end

    # @return [Array<String>, nil]
    attr_reader :parse

    # @return [Array<String, Integer>, nil]
    attr_reader :users

    # @return [Array<String, Integer>, nil]
    attr_reader :roles

    # @return [Boolean, nil]
    attr_reader :replied_user
    alias_method :replied_user?, :replied_user

    # When `strict` is enabled, parse is rejected from being combined with
    # explicit user/role IDs to prevent accidental pings.
    # @return [Boolean]
    attr_accessor :strict

    # @param parse [Array<"users", "roles", "everyone">, nil]
    # @param users [Array<User, String, Integer>, nil]
    # @param roles [Array<Role, String, Integer>, nil]
    # @param replied_user [Boolean, nil]
    # @param strict [Boolean] when true, additional validations prevent broad mentions.
    def initialize(parse: nil, users: nil, roles: nil, replied_user: nil, strict: false)
      @strict = strict

      self.parse = parse
      self.users = users
      self.roles = roles
      self.replied_user = replied_user
    end

    def self.none
      new(parse: [], users: [], roles: [], replied_user: false)
    end

    def self.all
      new(parse: %w[users roles everyone], replied_user: true)
    end

    # Validate and assign the parse list.
    def parse=(value)
      if value.nil?
        @parse = nil
        return
      end

      unless value.is_a?(Array)
        raise Error, "parse must be an Array, got #{value.class}"
      end

      normalized = value.map { |v| normalize_parse_value(v) }

      unless (normalized & PARSE_TYPES).size == normalized.size
        unknown = normalized - PARSE_TYPES
        raise Error, "Unknown parse values: #{unknown.inspect}"
      end

      @parse = normalized.uniq
      validate_no_conflict!
    end

    def users=(value)
      @users = assign_id_list(value, 'users')
      validate_no_conflict!
    end

    def roles=(value)
      @roles = assign_id_list(value, 'roles')
      validate_no_conflict!
    end

    def replied_user=(value)
      @replied_user = value.nil? ? nil : !!value
    end

    # @!visibility private
    def to_hash
      {
        parse: @parse&.dup,
        users: @users&.map { |u| u.is_a?(String) ? u : normalize_id_value(u) }&.dup,
        roles: @roles&.map { |r| r.is_a?(String) ? r : normalize_id_value(r) }&.dup,
        replied_user: @replied_user
      }.compact
    end

    private

    def assign_id_list(value, name)
      return nil if value.nil?

      raise Error, "#{name} must be an Array, got #{value.class}" unless value.is_a?(Array)

      if value.size > MAX_IDS
        raise Error, "#{name} cannot exceed #{MAX_IDS} IDs (got #{value.size})"
      end

      # Normalize each entry and de-duplicate while preserving order.
      seen = {}
      value.each { |v| seen[normalize_id_value(v)] = true }
      seen.keys
    end

    def normalize_id_value(value)
      if value.is_a?(IDObject)
        return value.id
      end

      if value.respond_to?(:resolve_id) && !value.is_a?(String) && !value.is_a?(Integer)
        return value.resolve_id
      end

      case value
      when Integer
        raise Error, "ID cannot be negative (#{value})" if value.negative?

        value.to_s
      when String
        raise Error, "Invalid snowflake: #{value.inspect}" unless SNOWFLAKE_PATTERN.match?(value)

        value
      else
        raise Error, "Unsupported #{value.class} as ID"
      end
    end

    def normalize_parse_value(value)
      case value
      when String then value
      when Symbol then value.to_s
      else
        raise Error, "Invalid parse value: #{value.inspect}"
      end
    end

    def validate_no_conflict!
      parse_set = @parse || []
      users_set = @users
      roles_set = @roles

      exclusions = []
      exclusions << '"users" in parse' if users_set && parse_set&.include?('users')
      exclusions << '"roles" in parse' if roles_set && parse_set&.include?('roles')

      unless exclusions.empty?
        raise Error, "Cannot combine parse=#{parse_set.inspect} with explicit #{exclusions.join(', ')}"
      end

      if @strict && parse_set&.include?('everyone')
        raise Error, 'strict mode rejects @everyone mentions; use parse=[:roles]' unless parse_set.length == 1
      end
    end
  end
end