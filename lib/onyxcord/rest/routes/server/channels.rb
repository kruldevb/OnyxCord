# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get a server's channels list
  # https://discord.com/developers/docs/resources/guild#get-guild-channels
  def channels(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_channels,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/channels",
      headers: { Authorization: token }
    )
  end

  # Create a channel
  # https://discord.com/developers/docs/resources/guild#create-guild-channel
  def create_channel(token, server_id, name, type, topic, bitrate, user_limit, permission_overwrites, parent_id, nsfw, rate_limit_per_user, position, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_channels,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/channels",
      body: { name: name, type: type, topic: topic, bitrate: bitrate, user_limit: user_limit, permission_overwrites: permission_overwrites, parent_id: parent_id, nsfw: nsfw, rate_limit_per_user: rate_limit_per_user, position: position }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Get the preview of a server.
  # https://discord.com/developers/docs/resources/guild#get-guild-preview
  def preview(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_preview,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/preview",
      headers: { Authorization: token }
    )
  end

  # Update a channels position
  # https://discord.com/developers/docs/resources/guild#modify-guild-channel-positions
  def update_channel_positions(token, server_id, positions)
    OnyxCord::REST.request(
      :guilds_sid_channels,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/channels",
      body: positions.to_json,
      headers: { Authorization: token, content_type: :json }
    )
  end
end
