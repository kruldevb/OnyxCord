# frozen_string_literal: true

# API calls for interactions — response management.
module OnyxCord::REST::Interaction
  module_function

  # Get the original response to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#get-original-interaction-response
  def get_original_interaction_response(interaction_token, application_id)
    OnyxCord::REST::Webhook.token_get_message(interaction_token, application_id, '@original')
  end

  # Edit the original response to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#edit-original-interaction-response
  def edit_original_interaction_response(interaction_token, application_id, content = nil, embeds = nil, allowed_mentions = nil, components = nil, attachments = nil, flags = nil, poll = nil)
    OnyxCord::REST::Webhook.token_edit_message(interaction_token, application_id, '@original', content, embeds, allowed_mentions, components, attachments, flags, poll)
  end

  # Delete the original response to an interaction.
  # https://discord.com/developers/docs/interactions/slash-commands#delete-original-interaction-response
  def delete_original_interaction_response(interaction_token, application_id)
    OnyxCord::REST::Webhook.token_delete_message(interaction_token, application_id, '@original')
  end
end
