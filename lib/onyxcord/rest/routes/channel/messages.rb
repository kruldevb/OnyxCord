# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Get a list of messages from a channel's history
  # https://discord.com/developers/docs/resources/channel#get-channel-messages
  def messages(token, channel_id, amount, before = nil, after = nil, around = nil)
    query_string = URI.encode_www_form({ limit: amount, before: before, after: after, around: around }.compact)
    OnyxCord::REST.request(
      :channels_cid_messages,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages?#{query_string}",
      Authorization: token
    )
  end

  # Get a single message from a channel's history by id
  # https://discord.com/developers/docs/resources/channel#get-channel-message
  def message(token, channel_id, message_id)
    OnyxCord::REST.request(
      :channels_cid_messages_mid,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token
    )
  end

  # Send a message to a channel
  # https://discord.com/developers/docs/resources/channel#create-message
  # @param attachments [Array<File>, nil] Attachments to use with `attachment://` in embeds. See
  #   https://discord.com/developers/docs/resources/channel#create-message-using-attachments-within-embeds
  def create_message(token, channel_id, message, tts = false, embeds = nil, nonce = nil, attachments = nil, allowed_mentions = nil, message_reference = nil, components = nil, flags = nil, enforce_nonce = false, poll = nil)
    tts = false unless [true, false].include?(tts)
    components = OnyxCord::MessageComponents.payload(components) unless components.nil?
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    OnyxCord::MessagePayload.validate!(content: message, embeds: embeds, components: components, flags: flags, attachments: attachments, poll: poll)
    body = { content: message, tts: tts == true, embeds: embeds, nonce: nonce, allowed_mentions: allowed_mentions, message_reference: message_reference, components: components, attachments: attachments ? attachment_payload(attachments) : nil, flags: flags, enforce_nonce: enforce_nonce, poll: poll }.compact
    body = if attachments
             multipart_body(body, attachments)
           else
             body.to_json
           end

    headers = { Authorization: token }
    headers[:content_type] = :json unless attachments

    OnyxCord::REST.request(
      :channels_cid_messages_mid,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages",
      body,
      **headers
    )
  end

  # Send a file as a message to a channel
  # https://discord.com/developers/docs/resources/channel#upload-file
  def upload_file(token, channel_id, file, caption: nil, tts: false)
    OnyxCord::REST.request(
      :channels_cid_messages_mid,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages",
      { file: file, content: caption, tts: tts },
      Authorization: token
    )
  end

  # Edit a message
  # https://discord.com/developers/docs/resources/channel#edit-message
  def edit_message(token, channel_id, message_id, message, mentions = nil, embeds = nil, components = nil, flags = nil)
    components = OnyxCord::MessageComponents.payload(components) unless components.nil? || components == :undef
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    body = OnyxCord::MessagePayload.edit_body(message, embeds)
    body.merge!(allowed_mentions: mentions, components: components, flags: flags)
    OnyxCord::REST.request(
      :channels_cid_messages_mid,
      channel_id,
      :patch,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}",
      body.reject { |_, v| v == :undef }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a message
  # https://discord.com/developers/docs/resources/channel#delete-message
  def delete_message(token, channel_id, message_id, reason = nil)
    OnyxCord::REST.request(
      :channels_cid_messages_mid,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Crosspost a message
  # https://discord.com/developers/docs/resources/message#crosspost-message
  def crosspost_message(token, channel_id, message_id)
    OnyxCord::REST.request(
      :channels_cid_messages_mid,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/crosspost",
      Authorization: token
    )
  end

  # Delete messages in bulk
  # https://discord.com/developers/docs/resources/channel#bulk-delete-messages
  def bulk_delete_messages(token, channel_id, messages = [], reason = nil)
    OnyxCord::REST.request(
      :channels_cid_messages_bulk_delete,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/bulk-delete",
      { messages: messages }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end
end
