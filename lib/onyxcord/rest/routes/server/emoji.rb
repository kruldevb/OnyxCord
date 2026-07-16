# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Adds a custom emoji.
  # https://discord.com/developers/docs/resources/emoji#create-guild-emoji
  def add_emoji(token, server_id, image, name, roles = [], reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_emojis,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/emojis",
      body: { image: image, name: name, roles: roles }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Changes an emoji name and/or roles.
  # https://discord.com/developers/docs/resources/emoji#modify-guild-emoji
  def edit_emoji(token, server_id, emoji_id, name, roles = nil, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_emojis_eid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/emojis/#{emoji_id}",
      body: { name: name, roles: roles }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Deletes a custom emoji
  # https://discord.com/developers/docs/resources/emoji#delete-guild-emoji
  def delete_emoji(token, server_id, emoji_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_emojis_eid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/emojis/#{emoji_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end
end
