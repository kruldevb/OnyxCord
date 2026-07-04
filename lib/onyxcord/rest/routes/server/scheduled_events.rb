# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get a list of all of the active scheduled events in the server.
  # https://discord.com/developers/docs/resources/guild-scheduled-event#list-scheduled-events-for-guild
  def list_scheduled_events(token, server_id, with_user_count: false)
    OnyxCord::REST.request(
      :guilds_sid_scheduled_events,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/scheduled-events?with_user_count=#{with_user_count}",
      Authorization: token
    )
  end

  # Get a single scheduled event in the server.
  # https://discord.com/developers/docs/resources/guild-scheduled-event#get-guild-scheduled-event
  def get_scheduled_event(token, server_id, scheduled_event_id, with_user_count: false)
    OnyxCord::REST.request(
      :guilds_sid_scheduled_events_seid,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/scheduled-events/#{scheduled_event_id}?with_user_count=#{with_user_count}",
      Authorization: token
    )
  end

  # Get a list of subscribers for a scheduled event in the server.
  # https://discord.com/developers/docs/resources/guild-scheduled-event#get-guild-scheduled-event-users
  def get_scheduled_event_users(token, server_id, scheduled_event_id, limit: 100, with_member: false, before: nil, after: nil)
    query = URI.encode_www_form({ limit:, with_member:, before:, after: }.compact)

    OnyxCord::REST.request(
      :guilds_sid_scheduled_events_seid_users,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/scheduled-events/#{scheduled_event_id}/users?#{query}",
      Authorization: token
    )
  end

  # Create a scheduled event in the server.
  # https://discord.com/developers/docs/resources/guild-scheduled-event#create-guild-scheduled-event
  def create_scheduled_event(token, server_id, name:, privacy_level:, scheduled_start_time:, entity_type:, channel_id: nil, entity_metadata: nil, scheduled_end_time: nil, description: nil, image: nil, recurrence_rule: nil, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_scheduled_events,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/scheduled-events",
      { name:, privacy_level:, scheduled_start_time:, entity_type:, channel_id:, entity_metadata:, scheduled_end_time:, description:, image:, recurrence_rule: }.compact.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update a scheduled event in the server.
  # https://discord.com/developers/docs/resources/guild-scheduled-event#modify-guild-scheduled-event
  def update_scheduled_event(token, server_id, scheduled_event_id, name: :undef, image: :undef, status: :undef, entity_type: :undef, privacy_level: :undef, scheduled_end_time: :undef, scheduled_start_time: :undef, channel_id: :undef, description: :undef, entity_metadata: :undef, recurrence_rule: :undef, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_scheduled_events_seid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/scheduled-events/#{scheduled_event_id}",
      { name:, image:, status:, entity_type:, privacy_level:, scheduled_end_time:, scheduled_start_time:, channel_id:, description:, entity_metadata:, recurrence_rule: }.reject { |_, value| value == :undef }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Delete a scheduled event in the server.
  # https://discord.com/developers/docs/resources/guild-scheduled-event#delete-guild-scheduled-event
  def delete_scheduled_event(token, server_id, scheduled_event_id, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_scheduled_events_seid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/scheduled-events/#{scheduled_event_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end
end
