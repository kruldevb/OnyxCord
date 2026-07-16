# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Create a webhook
  # https://discord.com/developers/docs/resources/webhook#create-webhook
  def create_webhook(token, channel_id, name, avatar = nil, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_webhooks,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/webhooks",
      body: { name: name, avatar: avatar }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Get channel webhooks
  # https://discord.com/developers/docs/resources/webhook#get-channel-webhooks
  def webhooks(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid_webhooks,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/webhooks",
      headers: { Authorization: token }
    )
  end

  # Follow an annoucement channel.
  # https://discord.com/developers/docs/resources/channel#follow-announcement-channel
  def follow_channel(token, channel_id, webhook_channel_id, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_followers,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/followers",
      body: { webhook_channel_id: webhook_channel_id }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end
end
