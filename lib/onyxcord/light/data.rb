# frozen_string_literal: true

require 'onyxcord/rest/client'
require 'onyxcord/light/attributes'

module OnyxCord::Light
  # Represents the bot account used for the light bot, but without any methods
  # to change anything. Only depends on {LightUserAttributes} (pure accessors)
  # — does NOT pull in the full {OnyxCord::UserAttributes} / models tree.
  class LightProfile
    include LightUserAttributes

    # @return [String, nil] email address. Only present with the `email` scope.
    #   `nil` means unknown (missing scope), not "no email".
    attr_reader :email

    # @return [true, false, nil] whether the account is verified.
    #   `nil` means unknown (missing `email` scope). Only meaningful with `email`.
    attr_reader :verified

    # @return [String, nil] the user's chosen locale.
    attr_reader :locale

    # @return [Integer, nil] the user's accent color.
    attr_reader :accent_color

    # @return [true, false, nil] whether the user is an official Discord System user.
    attr_reader :system_account

    alias_method :system_account?, :system_account

    # @return [true, false] whether the user is a fake user for a webhook message.
    attr_reader :webhook_account

    alias_method :webhook_account?, :webhook_account
    alias_method :webhook?, :webhook_account

    # @return [Hash, nil] raw `avatar_decoration_data` payload.
    attr_reader :avatar_decoration_data

    # @return [String, nil] avatar decoration preset hash (extracted from avatar_decoration_data).
    def avatar_decoration_id
      @avatar_decoration_data&.fetch('asset', nil)
    end

    alias_method :avatar_decoration_hash, :avatar_decoration_id

    # @return [Hash, nil] raw `collectibles` payload, or nil when absent.
    attr_reader :collectibles

    # @return [Hash, nil] raw `primary_guild` payload.
    attr_reader :primary_guild

    alias_method :primary_server, :primary_guild

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      raw = LightValidations.require_id!(data, 'LightProfile')

      @username = LightValidations.require_field!(data, 'username')
      @id = raw.to_i
      @discriminator = data['discriminator']
      @avatar_id = data['avatar']
      @global_name = data['global_name']
      @public_flags = data['public_flags']
      @bot_account = data['bot'] || false
      @webhook_account = data['_webhook'] || false
      @system_account = data['system']
      @banner_id = data['banner']
      @accent_color = data['accent_color']
      @locale = data['locale']
      @avatar_decoration_data = data['avatar_decoration_data']
      @collectibles = data['collectibles']
      @primary_guild = data['primary_guild']

      @email = data['email']
      @verified = data['verified']
    end

    # @return [true, false] whether this profile has the `email` scope data.
    def email_scope?
      !@email.nil?
    end
  end

  # A server that only has an icon, a name, and an ID associated with it, like
  # for example an integration's server.
  class UltraLightServer
    include LightServerAttributes

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      raw = LightValidations.require_id!(data, 'UltraLightServer')

      @id = raw.to_i
      @name = LightValidations.require_field!(data, 'name')
      @icon_id = data['icon']
    end
  end

  # Represents a light server which only has a fraction of the properties of any
  # other server.
  class LightServer < UltraLightServer
    # @return [true, false, nil] whether the LightBot is the owner of this server.
    #   `nil` means this information was not returned by the API.
    attr_reader :bot_is_owner

    alias_method :bot_is_owner?, :bot_is_owner

    # @return [OnyxCord::Permissions] the permissions the LightBot has on this server.
    attr_reader :bot_permissions

    # @!visibility private
    def initialize(data, bot)
      super(data, bot)

      @bot_is_owner = data['owner']
      @bot_permissions = OnyxCord::Permissions.new(data['permissions'] || 0)
    end
  end
end