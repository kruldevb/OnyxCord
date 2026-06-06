# frozen_string_literal: true

require 'onyxcord/data'

module OnyxCord::Light
  # Represents the bot account used for the light bot, but without any methods to change anything.
  class LightProfile
    include OnyxCord::IDObject
    include OnyxCord::UserAttributes

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @username = data['username']
      @id = data['id'].to_i
      @discriminator = data['discriminator']
      @avatar_id = data['avatar']

      @bot_account = false
      @bot_account = true if data['bot']

      @verified = data['verified']

      @email = data['email']
    end
  end

  # A server that only has an icon, a name, and an ID associated with it, like for example an integration's server.
  class UltraLightServer
    include OnyxCord::IDObject
    include OnyxCord::ServerAttributes

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i

      @name = data['name']
      @icon_id = data['icon']
    end
  end

  # Represents a light server which only has a fraction of the properties of any other server.
  class LightServer < UltraLightServer
    # @return [true, false] whether or not the LightBot this server belongs to is the owner of the server.
    attr_reader :bot_is_owner
    alias_method :bot_is_owner?, :bot_is_owner

    # @return [OnyxCord::Permissions] the permissions the LightBot has on this server
    attr_reader :bot_permissions

    # @!visibility private
    def initialize(data, bot)
      super(data, bot)

      @bot_is_owner = data['owner']
      @bot_permissions = OnyxCord::Permissions.new(data['permissions'])
    end
  end
end
