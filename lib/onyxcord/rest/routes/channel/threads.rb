# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Start a thread based off a channel message.
  # https://discord.com/developers/docs/resources/channel#start-thread-with-message
  def start_thread_with_message(token, channel_id, message_id, name, auto_archive_duration)
    OnyxCord::REST.request(
      :channels_cid_messages_mid_threads,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/messages/#{message_id}/threads",
      { name: name, auto_archive_duration: auto_archive_duration }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Start a thread without an associated message.
  # https://discord.com/developers/docs/resources/channel#start-thread-without-message
  def start_thread_without_message(token, channel_id, name, auto_archive_duration, type = 11)
    OnyxCord::REST.request(
      :channels_cid_threads,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/threads",
      { name: name, auto_archive_duration: auto_archive_duration, type: type },
      Authorization: token,
      content_type: :json
    )
  end

  # Add the current user to a thread.
  # https://discord.com/developers/docs/resources/channel#join-thread
  def join_thread(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid_thread_members_me,
      channel_id,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/thread-members/@me",
      nil,
      Authorization: token
    )
  end

  # Add a user to a thread.
  # https://discord.com/developers/docs/resources/channel#add-thread-member
  def add_thread_member(token, channel_id, user_id)
    OnyxCord::REST.request(
      :channels_cid_thread_members_uid,
      channel_id,
      :put,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/thread-members/#{user_id}",
      nil,
      Authorization: token
    )
  end

  # Remove the current user from a thread.
  # https://discord.com/developers/docs/resources/channel#leave-thread
  def leave_thread(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid_thread_members_me,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/thread-members/#{user_id}",
      Authorization: token
    )
  end

  # Remove a user from a thread.
  # https://discord.com/developers/docs/resources/channel#remove-thread-member
  def remove_thread_member(token, channel_id, user_id)
    OnyxCord::REST.request(
      :channels_cid_thread_members_uid,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/thread-members/#{user_id}",
      Authorization: token
    )
  end

  # Get the members of a thread.
  # https://discord.com/developers/docs/resources/channel#list-thread-members
  def list_thread_members(token, channel_id, before, limit)
    query = URI.encode_www_form({ before: before, limit: limit }.compact)

    OnyxCord::REST.request(
      :channels_cid_thread_members,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/thread-members?#{query}",
      Authorization: token
    )
  end

  # List active threads
  # https://discord.com/developers/docs/resources/channel#list-active-threads
  def list_active_threads(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid_threads_active,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/threads/active",
      Authorization: token
    )
  end

  # List public archived threads.
  # https://discord.com/developers/docs/resources/channel#list-public-archived-threads
  def list_public_archived_threads(token, channel_id, before = nil, limit = nil)
    query = URI.encode_www_form({ before: before, limit: limit }.compact)

    OnyxCord::REST.request(
      :channels_cid_threads_archived_public,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/threads/archived/public?#{query}",
      Authorization: token
    )
  end

  # List private archived threads.
  # https://discord.com/developers/docs/resources/channel#list-private-archived-threads
  def list_private_archived_threads(token, channel_id, before = nil, limit = nil)
    query = URI.encode_www_form({ before: before, limit: limit }.compact)

    OnyxCord::REST.request(
      :channels_cid_threads_archived_private,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/threads/archived/private?#{query}",
      Authorization: token
    )
  end

  # List joined private archived threads.
  # https://discord.com/developers/docs/resources/channel#list-joined-private-archived-threads
  def list_joined_private_archived_threads(token, channel_id, before = nil, limit = nil)
    query = URI.encode_www_form({ before: before, limit: limit }.compact)

    OnyxCord::REST.request(
      :channels_cid_users_me_threads_archived_private,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/users/@me/threads/archived/private?#{query}",
      Authorization: token
    )
  end

  # Start a thread in a forum or media channel.
  # https://discord.com/developers/docs/resources/channel#start-thread-in-forum-or-media-channel
  def start_thread_in_forum_or_media_channel(token, channel_id, name, message, attachments = nil, rate_limit_per_user = nil, auto_archive_duration = nil, applied_tags = nil, reason = nil)
    OnyxCord::MessagePayload.validate!(attachments: attachments)
    body = { name: name, message: message, rate_limit_per_user: rate_limit_per_user, auto_archive_duration: auto_archive_duration, applied_tags: applied_tags }.compact

    body = if attachments
             multipart_body(body, attachments)
           else
             body.to_json
           end

    headers = { Authorization: token, 'X-Audit-Log-Reason': reason }
    headers[:content_type] = :json unless attachments

    OnyxCord::REST.request(
      :channels_cid_threads,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/threads",
      body,
      headers
    )
  end
end
