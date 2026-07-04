# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get server prune count
  # https://discord.com/developers/docs/resources/guild#get-guild-prune-count
  def prune_count(token, server_id, days)
    OnyxCord::REST.request(
      :guilds_sid_prune,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/prune?days=#{days}",
      Authorization: token
    )
  end

  # Begin server prune
  # https://discord.com/developers/docs/resources/guild#begin-guild-prune
  def begin_prune(token, server_id, days, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_prune,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/prune",
      { days: days },
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Get invites from server
  # https://discord.com/developers/docs/resources/guild#get-guild-invites
  def invites(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_invites,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/invites",
      Authorization: token
    )
  end

  # Gets a server's audit logs
  # https://discord.com/developers/docs/resources/audit-log#get-guild-audit-log
  def audit_logs(token, server_id, limit, user_id = nil, action_type = nil, before = nil)
    OnyxCord::REST.request(
      :guilds_sid_auditlogs,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/audit-logs?limit=#{limit}#{"&user_id=#{user_id}" if user_id}#{"&action_type=#{action_type}" if action_type}#{"&before=#{before}" if before}",
      Authorization: token
    )
  end

  # Get server integrations
  # https://discord.com/developers/docs/resources/guild#get-guild-integrations
  def integrations(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_integrations,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/integrations",
      Authorization: token
    )
  end

  # Create a server integration
  # https://discord.com/developers/docs/resources/guild#create-guild-integration
  def create_integration(token, server_id, type, id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_integrations,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/integrations",
      { type: type, id: id },
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update integration from server
  # https://discord.com/developers/docs/resources/guild#modify-guild-integration
  def update_integration(token, server_id, integration_id, expire_behavior, expire_grace_period, enable_emoticons)
    OnyxCord::REST.request(
      :guilds_sid_integrations_iid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/integrations/#{integration_id}",
      { expire_behavior: expire_behavior, expire_grace_period: expire_grace_period, enable_emoticons: enable_emoticons }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Delete a server integration
  # https://discord.com/developers/docs/resources/guild#delete-guild-integration
  def delete_integration(token, server_id, integration_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_integrations_iid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/integrations/#{integration_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Sync an integration
  # https://discord.com/developers/docs/resources/guild#sync-guild-integration
  def sync_integration(token, server_id, integration_id)
    OnyxCord::REST.request(
      :guilds_sid_integrations_iid_sync,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/integrations/#{integration_id}/sync",
      nil,
      Authorization: token
    )
  end

  # Retrieves a server's widget information
  # https://discord.com/developers/docs/resources/guild#get-guild-widget
  def widget(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_embed,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/widget",
      Authorization: token
    )
  end
  alias embed widget

  # Modify a server's widget settings
  # https://discord.com/developers/docs/resources/guild#modify-guild-widget
  def modify_widget(token, server_id, enabled, channel_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_embed,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/widget",
      { enabled: enabled, channel_id: channel_id }.to_json,
      Authorization: token,
      'X-Audit-Log-Reason': reason,
      content_type: :json
    )
  end
  alias modify_embed modify_widget

  # Available voice regions for this server
  # https://discord.com/developers/docs/resources/guild#get-guild-voice-regions
  def regions(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_regions,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/regions",
      Authorization: token
    )
  end

  # Get server webhooks
  # https://discord.com/developers/docs/resources/webhook#get-guild-webhooks
  def webhooks(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_webhooks,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/webhooks",
      Authorization: token
    )
  end
end
