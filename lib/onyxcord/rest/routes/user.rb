# frozen_string_literal: true

# API calls for User object
module OnyxCord::REST::User
  module_function

  # Get user data
  # https://discord.com/developers/docs/resources/user#get-user
  def resolve(token, user_id)
    OnyxCord::REST.request(
      :users_uid,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/users/#{user_id}",
      headers: { Authorization: token }
    )
  end

  # Get profile data
  # https://discord.com/developers/docs/resources/user#get-current-user
  def profile(token)
    OnyxCord::REST.request(
      :users_me,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/users/@me",
      headers: { Authorization: token }
    )
  end

  # @deprecated Please use {OnyxCord::REST::Server.update_current_member} instead.
  # https://discord.com/developers/docs/resources/user#modify-current-user-nick
  def change_own_nickname(token, server_id, nick, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_members_me_nick,
      server_id, # This is technically a guild endpoint
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/@me/nick",
      body: { nick: nick }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # @deprecated Please use {update_current_user} instead.
  # https://discord.com/developers/docs/resources/user#modify-current-user
  def update_profile(token, _email, _password, new_username, avatar, _new_password = nil)
    update_current_user(token, new_username, avatar)
  end

  # Update the properties of the user for the current bot.
  # https://discord.com/developers/docs/resources/user#modify-current-user
  def update_current_user(token, username = :undef, avatar = :undef, banner = :undef)
    OnyxCord::REST.request(
      :users_me,
      nil,
      :patch,
      "#{OnyxCord::REST.api_base}/users/@me",
      body: { username: username, avatar: avatar, banner: banner }.reject { |_, value| value == :undef }.to_json,
      headers: { Authorization: token, content_type: :json }
    )
  end

  # Get the servers a user is connected to (single page)
  # https://discord.com/developers/docs/resources/user#get-current-user-guilds
  # @param limit [Integer, nil] max number of guilds per page (1-200, default 200)
  # @param before [String, Integer, nil] guild ID to get results before
  # @param after [String, Integer, nil] guild ID to get results after
  # @param with_counts [Boolean, nil] include approximate member and presence counts
  # @return [Array<Hash>] list of guild objects
  def servers(token, limit: nil, before: nil, after: nil, with_counts: nil)
    query = URI.encode_www_form({ limit: limit, before: before, after: after, with_counts: with_counts }.compact)
    OnyxCord::REST.request(
      :users_me_guilds,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/users/@me/guilds#{"?#{query}" unless query.empty?}",
      headers: { Authorization: token }
    )
  end

  # Enumerate all servers a user is connected to, automatically handling pagination.
  # Yields each guild page and optionally accumulates all results.
  # @param token [String] the bot token
  # @param max_items [Integer, nil] stop after fetching this many guilds (nil = all)
  # @param with_counts [Boolean, nil] include approximate member and presence counts
  # @param page_size [Integer] number of guilds per request (1-200, default 200)
  # @yield [Array<Hash>] each page of guild objects
  # @return [Array<Hash>] all guilds if no block given, otherwise the last page
  def enumerate_servers(token, max_items: nil, with_counts: nil, page_size: 200)
    collected = []
    after_id = nil
    remaining = max_items

    loop do
      page_limit = remaining ? [remaining, page_size].min : page_size
      page = servers(token, limit: page_limit, after: after_id, with_counts: with_counts)

      yield page if block_given?
      collected.concat(page)

      break if page.empty?
      break if remaining && (remaining -= page.size) <= 0

      after_id = page.last['id']
      break if page.size < page_limit
    end

    block_given? ? collected.last : collected
  end

  # Leave a server
  # https://discord.com/developers/docs/resources/user#leave-guild
  def leave_server(token, server_id)
    OnyxCord::REST.request(
      :users_me_guilds_sid,
      nil,
      :delete,
      "#{OnyxCord::REST.api_base}/users/@me/guilds/#{server_id}",
      headers: { Authorization: token }
    )
  end

  # Get the DM channels for the current user.
  # https://discord.com/developers/docs/resources/user#get-user-dms
  #
  # For bots, this returns DM channels the bot currently has open.
  # Most bot workflows should use {create_pm} to create a DM channel
  # with a specific user, then use the returned channel ID for messaging.
  #
  # @note This endpoint requires the `relationships.read` OAuth2 scope for user tokens.
  #   For bot tokens, it returns DMs the bot has already opened.
  # @param token [String] the bot or user OAuth2 token
  # @return [Array<Hash>] list of DM channel objects
  def user_dms(token)
    OnyxCord::REST.request(
      :users_me_channels,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/users/@me/channels",
      headers: { Authorization: token }
    )
  end

  # Create a DM to another user
  # https://discord.com/developers/docs/resources/user#create-dm
  def create_pm(token, recipient_id)
    OnyxCord::REST.request(
      :users_me_channels,
      nil,
      :post,
      "#{OnyxCord::REST.api_base}/users/@me/channels",
      body: { recipient_id: recipient_id }.to_json,
      headers: { Authorization: token, content_type: :json }
    )
  end

  # Get information about a user's connections
  # https://discord.com/developers/docs/resources/user#get-users-connections
  def connections(token)
    OnyxCord::REST.request(
      :users_me_connections,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/users/@me/connections",
      headers: { Authorization: token }
    )
  end

  # Returns one of the "default" discord avatars from the CDN given a discriminator or id since new usernames
  # TODO: Maybe change this method again after discriminator removal ?
  def default_avatar(discrim_id = 0, legacy: false)
    index = if legacy
              discrim_id.to_i % 5
            else
              (discrim_id.to_i >> 22) % 5
            end
    "#{OnyxCord::REST.cdn_url}/embed/avatars/#{index}.png"
  end

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id, format = nil)
    format ||= if avatar_id&.start_with?('a_')
                 'gif'
               else
                 'webp'
               end
    "#{OnyxCord::REST.cdn_url}/avatars/#{user_id}/#{avatar_id}.#{format}"
  end

  # Make a banner URL from the user and banner IDs
  def banner_url(user_id, banner_id, format = nil)
    format ||= if banner_id&.start_with?('a_')
                 'gif'
               else
                 'png'
               end
    "#{OnyxCord::REST.cdn_url}/banners/#{user_id}/#{banner_id}.#{format}"
  end
end
