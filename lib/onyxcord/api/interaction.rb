# frozen_string_literal: true

require 'onyxcord/message_components'

# API calls for interactions.
module OnyxCord::API::Interaction
  module_function

  # Build attachment metadata payload for multipart uploads.
  # Returns an array of { id:, filename: } hashes.
  def attachment_payload(attachments)
    Array(attachments).map.with_index do |attachment, index|
      { id: index, filename: File.basename(attachment.path) }
    end
  end

  # Build multipart body with named file fields and JSON payload.
  def multipart_body(body, attachments)
    files = Array(attachments).map.with_index.to_h do |attachment, index|
      ["files[#{index}]", attachment]
    end

    { **files, payload_json: body.to_json }
  end

  # Respond to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#create-interaction-response
  def create_interaction_response(interaction_token, interaction_id, type, content = nil, tts = nil, embeds = nil, allowed_mentions = nil, flags = nil, components = nil, attachments = nil, choices = nil, with_response = nil, poll = nil)
    components = OnyxCord::MessageComponents.payload(components) unless components.nil?
    flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)
    data = { tts: tts, content: content, embeds: embeds, allowed_mentions: allowed_mentions, flags: flags, components: components, attachments: attachments ? attachment_payload(attachments) : nil, choices: choices, poll: poll }.compact

    body = if attachments
             multipart_body({ type: type, data: data }, attachments)
           else
             { type: type, data: data }.to_json
           end

    headers = { content_type: :json } unless attachments

    OnyxCord::API.request(
      :interactions_iid_token_callback,
      interaction_id,
      :post,
      "#{OnyxCord::API.api_base}/interactions/#{interaction_id}/#{interaction_token}/callback?with_response=#{with_response ? 'true' : 'false'}",
      body,
      headers
    )
  end

  # Create a response that results in a modal.
  # https://discord.com/developers/docs/interactions/slash-commands#create-interaction-response
  def create_interaction_modal_response(interaction_token, interaction_id, custom_id, title, components)
    data = { custom_id: custom_id, title: title, components: components.to_a }.compact

    OnyxCord::API.request(
      :interactions_iid_token_callback,
      interaction_id,
      :post,
      "#{OnyxCord::API.api_base}/interactions/#{interaction_id}/#{interaction_token}/callback",
      { type: 9, data: data }.to_json,
      content_type: :json
    )
  end

  # Get the original response to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#get-original-interaction-response
  def get_original_interaction_response(interaction_token, application_id)
    OnyxCord::API::Webhook.token_get_message(interaction_token, application_id, '@original')
  end

  # Edit the original response to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#edit-original-interaction-response
  def edit_original_interaction_response(interaction_token, application_id, content = nil, embeds = nil, allowed_mentions = nil, components = nil, attachments = nil, flags = nil, poll = nil)
    OnyxCord::API::Webhook.token_edit_message(interaction_token, application_id, '@original', content, embeds, allowed_mentions, components, attachments, flags, poll)
  end

  # Delete the original response to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#delete-original-interaction-response
  def delete_original_interaction_response(interaction_token, application_id)
    OnyxCord::API::Webhook.token_delete_message(interaction_token, application_id, '@original')
  end
end
