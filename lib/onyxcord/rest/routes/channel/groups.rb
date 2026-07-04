# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Create an empty group channel.
  # @deprecated Discord no longer supports bots in group DMs, this endpoint was repurposed and no longer works as implemented here.
  # https://discord.com/developers/docs/resources/user#create-group-dm
  def create_empty_group(token, bot_user_id)
    OnyxCord::REST.request(
      :users_uid_channels,
      nil,
      :post,
      "#{OnyxCord::REST.api_base}/users/#{bot_user_id}/channels",
      {}.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Create a group channel.
  # @deprecated Discord no longer supports bots in group DMs, this endpoint was repurposed and no longer works as implemented here.
  # https://discord.com/developers/docs/resources/channel#group-dm-add-recipient
  def create_group(token, pm_channel_id, user_id)
    OnyxCord::REST.request(
      :channels_cid_recipients_uid,
      nil,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{pm_channel_id}/recipients/#{user_id}",
      {}.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Add a user to a group channel.
  # @deprecated Discord no longer supports bots in group DMs, this endpoint was repurposed and no longer works as implemented here.
  # https://discord.com/developers/docs/resources/channel#group-dm-add-recipient
  def add_group_user(token, group_channel_id, user_id)
    OnyxCord::REST.request(
      :channels_cid_recipients_uid,
      nil,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{group_channel_id}/recipients/#{user_id}",
      {}.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Remove a user from a group channel.
  # @deprecated Discord no longer supports bots in group DMs, this endpoint was repurposed and no longer works as implemented here.
  # https://discord.com/developers/docs/resources/channel#group-dm-remove-recipient
  def remove_group_user(token, group_channel_id, user_id)
    OnyxCord::REST.request(
      :channels_cid_recipients_uid,
      nil,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{group_channel_id}/recipients/#{user_id}",
      Authorization: token,
      content_type: :json
    )
  end

  # Leave a group channel.
  # @deprecated Discord no longer supports bots in group DMs, this endpoint was repurposed and no longer works as implemented here.
  # https://discord.com/developers/docs/resources/channel#deleteclose-channel
  def leave_group(token, group_channel_id)
    OnyxCord::REST.request(
      :channels_cid,
      nil,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{group_channel_id}",
      Authorization: token,
      content_type: :json
    )
  end
end
