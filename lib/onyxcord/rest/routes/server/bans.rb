# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get a server's banned users
  # https://discord.com/developers/docs/resources/guild#get-guild-bans
  def bans(token, server_id, limit = nil, before = nil, after = nil)
    query_string = URI.encode_www_form({ limit: limit, before: before, after: after }.compact)
    OnyxCord::REST.request(
      :guilds_sid_bans,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/bans?#{query_string}",
      Authorization: token
    )
  end

  # @deprecated Please use {ban_user!} instead.
  # https://discord.com/developers/docs/resources/guild#create-guild-ban
  def ban_user(token, server_id, user_id, message_days, reason = nil)
    ban_user!(token, server_id, user_id, message_days * 86_400, reason)
  end

  # Ban a user from a server and delete their messages up to a given amount of time.
  # https://discord.com/developers/docs/resources/guild#create-guild-ban
  def ban_user!(token, server_id, user_id, message_seconds, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_bans_uid,
      server_id,
      :put,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/bans/#{user_id}",
      { delete_message_seconds: message_seconds }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Unban a user from a server
  # https://discord.com/developers/docs/resources/guild#remove-guild-ban
  def unban_user(token, server_id, user_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_bans_uid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/bans/#{user_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Ban multiple users in one go
  # https://discord.com/developers/docs/resources/guild#bulk-guild-ban
  def bulk_ban(token, server_id, users, message_seconds, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_bulk_bans,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/bulk-ban",
      { user_ids: users, delete_message_seconds: message_seconds }.compact.to_json,
      content_type: :json,
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end
end
