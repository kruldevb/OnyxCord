# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get a member's data
  # https://discord.com/developers/docs/resources/guild#get-guild-member
  def resolve_member(token, server_id, user_id)
    OnyxCord::REST.request(
      :guilds_sid_members_uid,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/#{user_id}",
      headers: { Authorization: token }
    )
  end

  # Gets members from the server
  # https://discord.com/developers/docs/resources/guild#list-guild-members
  def resolve_members(token, server_id, limit, after = nil)
    query_string = URI.encode_www_form({ limit: limit, after: after }.compact)
    OnyxCord::REST.request(
      :guilds_sid_members,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members?#{query_string}",
      headers: { Authorization: token }
    )
  end

  # Search for a guild member
  # https://discord.com/developers/docs/resources/guild#search-guild-members
  def search_guild_members(token, server_id, query, limit)
    query_string = URI.encode_www_form({ query: query, limit: limit }.compact)
    OnyxCord::REST.request(
      :guilds_sid_members,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/search?#{query_string}",
      headers: { Authorization: token }
    )
  end

  # Update a user properties
  # https://discord.com/developers/docs/resources/guild#modify-guild-member
  def update_member(token, server_id, user_id, nick: :undef, roles: :undef, mute: :undef, deaf: :undef, channel_id: :undef,
                    communication_disabled_until: :undef, flags: :undef, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_members_uid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/#{user_id}",
      body: {
        roles: roles,
        nick: nick,
        mute: mute,
        deaf: deaf,
        channel_id: channel_id,
        communication_disabled_until: communication_disabled_until,
        flags: flags
      }.reject { |_, v| v == :undef }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Update the current member's properties.
  # https://discord.com/developers/docs/resources/guild#modify-current-member
  def update_current_member(token, server_id, nick = :undef, reason = nil, bio = :undef, banner = :undef, avatar = :undef)
    OnyxCord::REST.request(
      :guilds_sid_members_me,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/@me",
      body: { nick: nick, bio: bio, banner: banner, avatar: avatar }.reject { |_, v| v == :undef }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Remove user from server
  # https://discord.com/developers/docs/resources/guild#remove-guild-member
  def remove_member(token, server_id, user_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_members_uid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/#{user_id}",
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Adds a member to a server with an OAuth2 Bearer token that has been granted `guilds.join`
  # https://discord.com/developers/docs/resources/guild#add-guild-member
  def add_member(token, server_id, user_id, access_token, nick = nil, roles = [], mute = false, deaf = false)
    OnyxCord::REST.request(
      :guilds_sid_members_uid,
      server_id,
      :put,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/#{user_id}",
      body: { access_token: access_token, nick: nick, roles: roles, mute: mute, deaf: deaf }.to_json,
      headers: { content_type: :json, Authorization: token }
    )
  end
end
