# frozen_string_literal: true

require 'onyxcord/message_components'

# API calls for Webhook object
module OnyxCord::API::Webhook
  module_function

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
    components = OnyxCord::MessageComponents.payload(components) unless components.nil?
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    body = { content: content, username: username, avatar_url: avatar_url, tts: tts, embeds: embeds&.map(&:to_hash),  allowed_mentions: allowed_mentions, flags: flags, components: components, poll: poll }

    body = if file
             { file: file, payload_json: body.to_json }
           elsif attachments
             files = [*0...attachments.size].zip(attachments).to_h
             { **files, payload_json: body.to_json }
           else
             body.to_json
           end

    headers = { content_type: :json } unless file || attachments
    with_components = components&.any? ? true : nil
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
    body = { content: content, embeds: embeds, allowed_mentions: allowed_mentions, components: components, flags: flags, poll: poll }

    body = if attachments
             files = [*0...attachments.size].zip(attachments).to_h
             { **files, payload_json: body.to_json }
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
