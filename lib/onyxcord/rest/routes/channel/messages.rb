# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Get a list of messages from a channel's history
  # https://discord.com/developers/docs/resources/channel#get-channel-messages
  def messages(token, channel_id, amount, before = nil, after = nil, around = nil)
    pagination_params = [before, after, around].compact
    if pagination_params.size > 1
      raise ArgumentError, 'Only one of before, after, or around may be specified'
    end

    limit = amount.to_i
    unless limit >= 1 && limit <= 100
      raise ArgumentError, "limit must be between 1 and 100, got #{limit}"
    end

    query_string = URI.encode_www_form({ limit: limit, before: before, after: after, around: around }.compact)
    OnyxCord::REST.request(
      :channels_cid_messages,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages?#{query_string}",
      headers: { Authorization: token }
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
      headers: { Authorization: token }
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
    payload = { content: message, tts: tts == true, embeds: embeds, nonce: nonce, allowed_mentions: allowed_mentions, message_reference: message_reference, components: components, attachments: attachments ? attachment_payload(attachments) : nil, flags: flags, enforce_nonce: enforce_nonce, poll: poll }.compact
    body = if attachments
             multipart_body(payload, attachments)
           else
             payload.to_json
           end

    headers = { Authorization: token }
    headers[:content_type] = :json unless attachments

    OnyxCord::REST.request(
      :channels_cid_messages,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages",
      body: body,
      headers: headers
    )
  end

  # Send a file as a message to a channel
  # https://discord.com/developers/docs/resources/channel#upload-file
  def upload_file(token, channel_id, file, caption: nil, tts: false)
    body = { file: file, content: caption, tts: tts }
    OnyxCord::REST.request(
      :channels_cid_messages,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages",
      body: body,
      headers: { Authorization: token }
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
      body: body.reject { |_, v| v == :undef }.to_json,
      headers: { Authorization: token, content_type: :json }
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
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
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
      headers: { Authorization: token }
    )
  end

  # Delete messages in bulk
  # https://discord.com/developers/docs/resources/channel#bulk-delete-messages
  def bulk_delete_messages(token, channel_id, messages = [], reason = nil)
    messages = messages.uniq
    unless messages.size >= 2 && messages.size <= 100
      raise ArgumentError, "Must provide between 2 and 100 message IDs, got #{messages.size}"
    end

    # Discord rejects messages older than 14 days in bulk delete
    two_weeks_ago = (Time.now - 14 * 24 * 60 * 60).to_i << 22
    messages.each do |msg_id|
      id = msg_id.to_i
      if id < two_weeks_ago
        raise ArgumentError, "Message #{msg_id} is older than 14 days and cannot be bulk-deleted"
      end
    end

    OnyxCord::REST.request(
      :channels_cid_messages_bulk_delete,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/bulk-delete",
      body: { messages: messages.map(&:to_s) }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end
end
