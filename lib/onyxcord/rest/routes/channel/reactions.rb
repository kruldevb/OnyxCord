# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Create a reaction on a message using this client
  # https://discord.com/developers/docs/resources/channel#create-reaction
  def create_reaction(token, channel_id, message_id, emoji)
    emoji = URI.encode_www_form_component(emoji) unless emoji.ascii_only?
    OnyxCord::REST.request(
      :channels_cid_messages_mid_reactions_emoji_me,
      channel_id,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me",
      nil,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete this client's own reaction on a message
  # https://discord.com/developers/docs/resources/channel#delete-own-reaction
  def delete_own_reaction(token, channel_id, message_id, emoji)
    emoji = URI.encode_www_form_component(emoji) unless emoji.ascii_only?
    OnyxCord::REST.request(
      :channels_cid_messages_mid_reactions_emoji_me,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me",
      Authorization: token
    )
  end

  # Delete another client's reaction on a message
  # https://discord.com/developers/docs/resources/channel#delete-user-reaction
  def delete_user_reaction(token, channel_id, message_id, emoji, user_id)
    emoji = URI.encode_www_form_component(emoji) unless emoji.ascii_only?
    OnyxCord::REST.request(
      :channels_cid_messages_mid_reactions_emoji_uid,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/#{user_id}",
      Authorization: token
    )
  end

  # Get a list of clients who reacted with a specific reaction on a message
  # https://discord.com/developers/docs/resources/channel#get-reactions
  def get_reactions(token, channel_id, message_id, emoji, before_id, after_id, limit = 100, type = 0)
    emoji = URI.encode_www_form_component(emoji) unless emoji.ascii_only?
    query_string = URI.encode_www_form({ limit: limit || 100, before: before_id, after: after_id, type: type }.compact)
    OnyxCord::REST.request(
      :channels_cid_messages_mid_reactions_emoji,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}?#{query_string}",
      Authorization: token
    )
  end

  # Deletes all reactions on a message from all clients
  # https://discord.com/developers/docs/resources/channel#delete-all-reactions
  def delete_all_reactions(token, channel_id, message_id)
    OnyxCord::REST.request(
      :channels_cid_messages_mid_reactions,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/reactions",
      Authorization: token
    )
  end

  # Deletes all the reactions for a given emoji on a message
  # https://discord.com/developers/docs/resources/channel#delete-all-reactions-for-emoji
  def delete_all_emoji_reactions(token, channel_id, message_id, emoji)
    emoji = URI.encode_www_form_component(emoji) unless emoji.ascii_only?

    OnyxCord::REST.request(
      :channels_cid_messages_mid_reactions_emoji,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}",
      Authorization: token
    )
  end
end
