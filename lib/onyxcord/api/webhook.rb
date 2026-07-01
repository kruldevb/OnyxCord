# frozen_string_literal: true

require 'onyxcord/message_payload'

# API calls for Webhook object
module OnyxCord::API::Webhook
  module_function

  # Build attachment metadata payload for multipart uploads.
  # Returns an array of { id:, filename: } hashes.
  def attachment_payload(attachments)
    OnyxCord::MessagePayload.attachment_payload(attachments)
  end

  # Build multipart body with named file fields and JSON payload.
  def multipart_body(body, attachments)
    OnyxCord::MessagePayload.multipart_body(body, attachments)
  end

  # Get a webhook
  # https://discord.com/developers/docs/resources/webhook#get-webhook
  def webhook(token, webhook_id)
    OnyxCord::API.request(
      :webhooks_wid,
      nil,
      :get,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}",
      Authorization: token
    )
  end

  # Get a webhook via webhook token
  # https://discord.com/developers/docs/resources/webhook#get-webhook-with-token
  def token_webhook(webhook_token, webhook_id)
    OnyxCord::API.request(
      :webhooks_wid,
      nil,
      :get,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}"
    )
  end

  # Execute a webhook via token.
  # https://discord.com/developers/docs/resources/webhook#execute-webhook
  def token_execute_webhook(webhook_token, webhook_id, wait = false, content = nil, username = nil, avatar_url = nil, tts = nil, file = nil, embeds = nil, allowed_mentions = nil, flags = nil, components = nil, attachments = nil, poll = nil)
    raise ArgumentError, 'cannot mix file and attachments' if file && attachments

    components = OnyxCord::MessageComponents.payload(components) unless components.nil?
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    OnyxCord::MessagePayload.validate!(content: content, embeds: embeds, components: components, flags: flags, attachments: attachments, poll: poll)
    body = { content: content, username: username, avatar_url: avatar_url, tts: tts == true ? true : nil, embeds: embeds&.map(&:to_hash), allowed_mentions: allowed_mentions, flags: flags, components: components&.any? ? components : nil, attachments: attachments ? attachment_payload(attachments) : nil, poll: poll }.compact

    body = if file
             { file: file, payload_json: body.to_json }
           elsif attachments
             multipart_body(body, attachments)
           else
             body.to_json
           end

    headers = { content_type: :json } unless file || attachments
    with_components = components&.any? || nil
    query = URI.encode_www_form({ wait: wait, with_components: with_components }.compact)

    OnyxCord::API.request(
      :webhooks_wid,
      webhook_id,
      :post,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}?#{query}",
      body,
      headers
    )
  end

  # Update a webhook
  # https://discord.com/developers/docs/resources/webhook#modify-webhook
  def update_webhook(token, webhook_id, data, reason = nil)
    OnyxCord::API.request(
      :webhooks_wid,
      webhook_id,
      :patch,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}",
      data.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update a webhook via webhook token
  # https://discord.com/developers/docs/resources/webhook#modify-webhook-with-token
  def token_update_webhook(webhook_token, webhook_id, data, reason = nil)
    OnyxCord::API.request(
      :webhooks_wid,
      webhook_id,
      :patch,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}",
      data.to_json,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Deletes a webhook
  # https://discord.com/developers/docs/resources/webhook#delete-webhook
  def delete_webhook(token, webhook_id, reason = nil)
    OnyxCord::API.request(
      :webhooks_wid,
      webhook_id,
      :delete,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Deletes a webhook via webhook token
  # https://discord.com/developers/docs/resources/webhook#delete-webhook-with-token
  def token_delete_webhook(webhook_token, webhook_id, reason = nil)
    OnyxCord::API.request(
      :webhooks_wid,
      webhook_id,
      :delete,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}",
      'X-Audit-Log-Reason': reason
    )
  end

  # Get a message that was created by the webhook corresponding to the provided token.
  # https://discord.com/developers/docs/resources/webhook#get-webhook-message
  def token_get_message(webhook_token, webhook_id, message_id)
    OnyxCord::API.request(
      :webhooks_wid_messages_mid,
      webhook_id,
      :get,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}"
    )
  end

  # Edit a webhook message via webhook token
  # https://discord.com/developers/docs/resources/webhook#edit-webhook-message
  def token_edit_message(webhook_token, webhook_id, message_id, content = nil, embeds = nil, allowed_mentions = nil, components = nil, attachments = nil, flags = nil, poll = nil)
    components = OnyxCord::MessageComponents.payload(components) unless components.nil?
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    OnyxCord::MessagePayload.validate!(content: content, embeds: embeds, components: components, flags: flags, attachments: attachments, poll: poll)
    body = OnyxCord::MessagePayload.edit_body(content, embeds).merge({ allowed_mentions: allowed_mentions, components: components, attachments: attachments ? attachment_payload(attachments) : nil, flags: flags, poll: poll }.compact)

    body = if attachments
             multipart_body(body, attachments)
           else
             body.to_json
           end

    headers = { content_type: :json } unless attachments

    OnyxCord::API.request(
      :webhooks_wid_messages,
      webhook_id,
      :patch,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}",
      body,
      headers
    )
  end

  # Delete a webhook message via webhook token.
  # https://discord.com/developers/docs/resources/webhook#delete-webhook-message
  def token_delete_message(webhook_token, webhook_id, message_id)
    OnyxCord::API.request(
      :webhooks_wid_messages,
      webhook_id,
      :delete,
      "#{OnyxCord::API.api_base}/webhooks/#{webhook_id}/#{webhook_token}/messages/#{message_id}"
    )
  end
end
