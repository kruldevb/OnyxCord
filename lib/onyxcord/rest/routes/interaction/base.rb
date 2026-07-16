# frozen_string_literal: true

require 'onyxcord/internal/message_payload'

# API calls for interactions — base response methods.
module OnyxCord::REST::Interaction
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

  # Respond to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#create-interaction-response
  def create_interaction_response(interaction_token, interaction_id, type, content = nil, tts = nil, embeds = nil, allowed_mentions = nil, flags = nil, components = nil, attachments = nil, choices = nil, with_response = nil, poll = nil)
    components = OnyxCord::MessageComponents.payload(components) unless components.nil?
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    OnyxCord::MessagePayload.validate!(content: content, embeds: embeds, components: components, flags: flags, attachments: attachments, poll: poll)
    data = { tts: tts, content: content, embeds: embeds, allowed_mentions: allowed_mentions, flags: flags, components: components, attachments: attachments ? attachment_payload(attachments) : nil, choices: choices, poll: poll }.compact

    body = if attachments
             multipart_body({ type: type, data: data }, attachments)
           else
             { type: type, data: data }.to_json
           end

    headers = { content_type: :json } unless attachments

    OnyxCord::REST.request(
      :interactions_iid_token_callback,
      interaction_id,
      :post,
      "#{OnyxCord::REST.api_base}/interactions/#{interaction_id}/#{interaction_token}/callback?with_response=#{with_response ? 'true' : 'false'}",
      body: body,
      headers: headers || {}
    )
  end

  # Create a response that results in a modal.
  # https://discord.com/developers/docs/interactions/slash-commands#create-interaction-response
  def create_interaction_modal_response(interaction_token, interaction_id, custom_id, title, components)
    data = { custom_id: custom_id, title: title, components: components.to_a }.compact

    OnyxCord::REST.request(
      :interactions_iid_token_callback,
      interaction_id,
      :post,
      "#{OnyxCord::REST.api_base}/interactions/#{interaction_id}/#{interaction_token}/callback",
      body: { type: 9, data: data }.to_json,
      headers: { content_type: :json }
    )
  end
end
