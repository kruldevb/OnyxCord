# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Get a list of pinned messages in a channel
  # https://discord.com/developers/docs/resources/message#get-channel-pins
  def pinned_messages(token, channel_id, limit = 50, before = nil)
    query = URI.encode_www_form({ limit: limit, before: before }.compact)
    OnyxCord::REST.request(
      :channels_cid_pins,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/pins?#{query}",
      Authorization: token
    )
  end

  # Pin a message
  # https://discord.com/developers/docs/resources/message#pin-message
  def pin_message(token, channel_id, message_id, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_pins_mid,
      channel_id,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/pins/#{message_id}",
      nil,
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Unpin a message
  # https://discord.com/developers/docs/resources/message#unpin-message
  def unpin_message(token, channel_id, message_id, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_pins_mid,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/pins/#{message_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end
end
