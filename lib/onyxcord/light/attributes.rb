# frozen_string_literal: true

require 'onyxcord/utils/id_object'
require 'onyxcord/utils/permissions'

module OnyxCord::Light
  # Minimal User attributes mixin for Light models. Contains only pure
  # presentation/comparison methods that work exclusively with data already
  # received — no gateway, no Discord objects, no hidden REST calls.
  #
  # Replaces the full {OnyxCord::UserAttributes} inclusion that brought in the
  # entire models tree (~38 files, ~9,971 lines) just for a handful of getters.
  module LightUserAttributes
    # @return [Integer] the ID which uniquely identifies this object across Discord.
    def id
      @id.to_i
    end

    alias_method :resolve_id, :id
    alias_method :hash, :id

    # @return [String] this user's username.
    def username
      @username
    end

    alias_method :name, :username

    # @return [String, nil] this user's global display name.
    def global_name
      @global_name
    end

    # @return [String, nil] this user's discriminator.
    def discriminator
      @discriminator
    end

    # @return [true, false] whether this user is a Discord bot account.
    def bot_account
      !!@bot_account
    end

    alias_method :bot_account?, :bot_account

    # @return [String] the ID of this user's current avatar.
    def avatar_id
      @avatar_id
    end

    # @return [Integer] the public flags bitfield on this user's account, or 0 when absent.
    def public_flags
      @public_flags || 0
    end

    # Public flags recognized by OnyxCord. Same values as
    # {OnyxCord::UserAttributes::FLAGS}; copied here so the light path does
    # not need to load the full models tree.
    FLAGS = {
      staff: 1 << 0,
      partner: 1 << 1,
      hypesquad: 1 << 2,
      bug_hunter_level_1: 1 << 3,
      hypesquad_online_house_1: 1 << 6,
      hypesquad_online_house_2: 1 << 7,
      hypesquad_online_house_3: 1 << 8,
      premium_early_supporter: 1 << 9,
      team_pseudo_user: 1 << 10,
      bug_hunter_level_2: 1 << 14,
      verified_bot: 1 << 16,
      verified_developer: 1 << 17,
      certified_moderator: 1 << 18,
      bot_http_interactions: 1 << 19,
      active_developer: 1 << 22
    }.freeze

    FLAGS.each_key do |name|
      define_method("#{name}?") do
        public_flags.anybits?(FLAGS[name])
      end
    end

    # @return [String] the name the user displays as.
    def display_name
      global_name || username
    end

    # @return [String] mention code `<@id>`.
    def mention
      "<@#{id}>"
    end

    # @return [String] distinct representation (username#discriminator).
    def distinct
      if @discriminator && @discriminator != '0'
        "#{@username}##{@discriminator}"
      else
        @username.to_s
      end
    end

    # @param format [String, nil]
    # @return [String] the URL to this user's avatar image.
    def avatar_url(format = nil)
      unless @avatar_id
        return OnyxCord::REST::User.default_avatar(@discriminator, legacy: true) if @discriminator && @discriminator != '0'

        return OnyxCord::REST::User.default_avatar(id)
      end

      OnyxCord::REST::User.avatar_url(id, @avatar_id, format)
    end

    # @param format [String, nil]
    # @return [String, nil] the URL to this user's banner image, or nil when absent.
    #   Works exclusively with the banner data already received from the API;
    #   never issues a new REST request.
    def banner_url(format = nil)
      return unless @banner_id

      OnyxCord::REST::User.banner_url(id, @banner_id, format)
    end

    # Utility function to get Discord's avatar decoration URL.
    # @return [String, nil] the URL to this user's avatar decoration, or nil when absent.
    def avatar_decoration_url(format = 'png')
      return unless @avatar_decoration_id

      OnyxCord::REST.avatar_decoration_url(@avatar_decoration_id, format)
    end

    # @return [Integer] the estimated creation time of this object.
    def creation_time
      ms = (id >> 22) + OnyxCord::DISCORD_EPOCH
      Time.at(ms / 1000.0)
    end

    # ID-based equality.
    def ==(other)
      OnyxCord.id_compare?(id, other)
    end

    alias_method :eql?, :==

    # @return [String] redacted inspect never leaking credentials.
    def inspect
      attrs = %i[@username @id @global_name].map { |name| "#{name}=#{instance_variable_get(name)}" }
      "#<#{self.class.name} #{attrs.join(' ')}>"
    end
  end

  # Minimal Server attributes mixin. Only name, icon URL and presentation
  # methods. No dependency on {OnyxCord::ServerAttributes} / full server tree.
  module LightServerAttributes
    # @return [Integer] the server's ID.
    def id
      @id.to_i
    end

    alias_method :resolve_id, :id

    # @return [String] this server's name.
    def name
      @name
    end

    # @return [String, nil] the ID of this server's icon.
    def icon_id
      @icon_id
    end

    # @return [String, nil] the URL to this server's icon.
    def icon_url(format: 'webp')
      return unless @icon_id

      OnyxCord::REST.icon_url(id, @icon_id, format)
    end

    # @return [String] URL for navigating to this server in the client.
    def link
      "https://discord.com/channels/#{id}"
    end

    alias_method :jump_link, :link

    def inspect
      "#<#{self.class.name} name=#{@name.inspect} id=#{id}>"
    end
  end

  # Schema validation helpers. Shared across Light models so invalid payloads
  # (e.g. missing `id`) raise a descriptive error instead of silently creating
  # objects with ID 0.
  module LightValidations
    module_function

    def require_field!(data, field)
      value = data[field]
      return value unless value.nil?

      raise ArgumentError, "Payload missing required field '#{field}'. " \
                           "Ensure your OAuth2 scopes include the data needed for this endpoint."
    end

    def require_id!(data, klass_name)
      raw = data['id']
      unless raw
        raise ArgumentError, "Missing 'id' in #{klass_name} payload. " \
                             'Check scopes and ensure the endpoint returned the expected data.'
      end
      raw.to_s
    end
  end
end