# frozen_string_literal: true

module OnyxCord::REST::Channel
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

  # Get a channel's data
  # https://discord.com/developers/docs/resources/channel#get-channel
  def resolve(token, channel_id)
    OnyxCord::REST.request(
      :channels_cid,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}",
      headers: { Authorization: token }
    )
  end

  # Update a channel's data
  # https://discord.com/developers/docs/resources/channel#modify-channel
  def update(token, channel_id, name, topic, position, bitrate, user_limit, nsfw, permission_overwrites = nil, parent_id = nil, rate_limit_per_user = nil, reason = nil, archived = nil, auto_archive_duration = nil, locked = nil, invitable = nil, flags = nil, applied_tags = nil)
    data = { name: name, position: position, topic: topic, bitrate: bitrate, user_limit: user_limit, nsfw: nsfw, parent_id: parent_id, rate_limit_per_user: rate_limit_per_user, archived: archived, auto_archive_duration: auto_archive_duration, locked: locked, invitable: invitable, flags: flags, applied_tags: applied_tags }
    data[:permission_overwrites] = permission_overwrites unless permission_overwrites.nil?
    OnyxCord::REST.request(
      :channels_cid,
      channel_id,
      :patch,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}",
      body: data.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Modify the properties of a channel.
  # https://discord.com/developers/docs/resources/channel#modify-channel
  def update!(token, channel_id, name: :undef, type: :undef, position: :undef, topic: :undef, nsfw: :undef, rate_limit_per_user: :undef, bitrate: :undef, user_limit: :undef, permission_overwrites: :undef, parent_id: :undef, rtc_region: :undef, video_quality_mode: :undef, default_auto_archive_duration: :undef, flags: :undef, available_tags: :undef, default_reaction_emoji: :undef, default_thread_rate_limit_per_user: :undef, default_sort_order: :undef, default_forum_layout: :undef, archived: :undef, auto_archive_duration: :undef, locked: :undef, invitable: :undef, applied_tags: :undef, reason: nil)
    OnyxCord::REST.request(
      :channels_cid,
      channel_id,
      :patch,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}",
      body: { name:, type:, position:, topic:, nsfw:, rate_limit_per_user:, bitrate:, user_limit:, permission_overwrites:, parent_id:, rtc_region:, video_quality_mode:, default_auto_archive_duration:, flags:, available_tags:, default_reaction_emoji:, default_thread_rate_limit_per_user:, default_sort_order:, default_forum_layout:, archived:, auto_archive_duration:, locked:, invitable:, applied_tags: }.reject { |_, value| value == :undef }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Delete a channel
  # https://discord.com/developers/docs/resources/channel#deleteclose-channel
  def delete(token, channel_id, reason = nil)
    OnyxCord::REST.request(
      :channels_cid,
      channel_id,
      :delete,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end
end
