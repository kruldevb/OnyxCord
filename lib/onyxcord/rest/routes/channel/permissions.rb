# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Update a channels permission for a role or member
  # https://discord.com/developers/docs/resources/channel#edit-channel-permissions
  def update_permission(token, channel_id, overwrite_id, allow, deny, type, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_permissions_oid,
      channel_id,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/permissions/#{overwrite_id}",
      body: { type: type, id: overwrite_id, allow: allow, deny: deny }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Get a channel's invite list
  # https://discord.com/developers/docs/resources/channel#get-channel-invites
  def invites(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid_invites,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/invites",
      headers: { Authorization: token }
    )
  end

  # Create an instant invite from a server or a channel id
  # https://discord.com/developers/docs/resources/channel#create-channel-invite
  def create_invite(token, channel_id, max_age = 0, max_uses = 0, temporary = false, unique = false, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_invites,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/invites",
      body: { max_age: max_age, max_uses: max_uses, temporary: temporary, unique: unique }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Delete channel permission
  # https://discord.com/developers/docs/resources/channel#delete-channel-permission
  def delete_permission(token, channel_id, overwrite_id, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_permissions_oid,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/permissions/#{overwrite_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # Start typing (needs to be resent every 5 seconds to keep up the typing)
  # https://discord.com/developers/docs/resources/channel#trigger-typing-indicator
  def start_typing(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid_typing,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/typing",
      headers: { Authorization: token }
    )
  end
end
