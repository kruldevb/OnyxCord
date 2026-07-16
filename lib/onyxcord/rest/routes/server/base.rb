# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get a server's data
  # https://discord.com/developers/docs/resources/guild#get-guild
  def resolve(token, server_id, with_counts = nil)
    query = URI.encode_www_form({ with_counts: with_counts ? 'true' : nil }.compact)
    OnyxCord::REST.request(
      :guilds_sid,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}#{"?#{query}" unless query.empty?}",
      headers: { Authorization: token }
    )
  end

  # Update a server
  # https://discord.com/developers/docs/resources/guild#modify-guild
  def update(token, server_id, name, region, icon, afk_channel_id, afk_timeout, splash, default_message_notifications, verification_level, explicit_content_filter, system_channel_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}",
      body: { name: name, region: region, icon: icon, afk_channel_id: afk_channel_id, afk_timeout: afk_timeout, splash: splash, default_message_notifications: default_message_notifications, verification_level: verification_level, explicit_content_filter: explicit_content_filter, system_channel_id: system_channel_id }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Update the properties of a guild.
  # https://discord.com/developers/docs/resources/guild#modify-guild
  def update!(token, server_id, name: :undef, region: :undef, verification_level: :undef, default_message_notifications: :undef, explicit_content_filter: :undef, afk_channel_id: :undef, afk_timeout: :undef, icon: :undef, splash: :undef, discovery_splash: :undef, banner: :undef, system_channel_id: :undef, system_channel_flags: :undef, rules_channel_id: :undef, public_updates_channel_id: :undef, preferred_locale: :undef, features: :undef, description: :undef, premium_progress_bar_enabled: :undef, safety_alerts_channel_id: :undef, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}",
      body: { name:, region:, verification_level:, default_message_notifications:, explicit_content_filter:, afk_channel_id:, afk_timeout:, icon:, splash:, discovery_splash:, banner:, system_channel_id:, system_channel_flags:, rules_channel_id:, public_updates_channel_id:, preferred_locale:, features:, description:, premium_progress_bar_enabled:, safety_alerts_channel_id: }.reject { |_, value| value == :undef }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Modify the incident actions for a server.
  # https://discord.com/developers/docs/resources/guild#modify-guild-incident-actions
  def update_incident_actions(token, server_id, invites_disabled_until: :undef, dms_disabled_until: :undef, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_incidents_actions,
      server_id,
      :put,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/incident-actions",
      body: { invites_disabled_until:, dms_disabled_until: }.reject { |_, value| value == :undef }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end

  # Modify the properties of a widget for a server.
  # https://docs.discord.com/developers/resources/guild#modify-guild-widget
  def update_widget(token, server_id, enabled: :undef, channel_id: :undef, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_widget,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/widget",
      body: { enabled:, channel_id: }.reject { |_, value| value == :undef }.to_json,
      headers: { Authorization: token, content_type: :json, 'X-Audit-Log-Reason': reason }
    )
  end
end
