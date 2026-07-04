# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Get server roles
  # https://discord.com/developers/docs/resources/guild#get-guild-roles
  def roles(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_roles,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles",
      Authorization: token
    )
  end

  # Get a single role
  # https://discord.com/developers/docs/resources/guild#get-guild-role
  def role(token, server_id, role_id)
    OnyxCord::REST.request(
      :guilds_sid_roles_rid,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles/#{role_id}",
      Authorization: token
    )
  end

  # Create a role (parameters such as name and colour if not set can be set by update_role afterwards)
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discord.com/developers/docs/resources/guild#get-guild-roles
  def create_role(token, server_id, name, colour, hoist, mentionable, packed_permissions, reason = nil, colours = nil, icon = nil, unicode_emoji = nil)
    OnyxCord::REST.request(
      :guilds_sid_roles,
      server_id,
      :post,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles",
      { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions, colors: colours, icon: icon, unicode_emoji: unicode_emoji }.compact.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update a role
  # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
  # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
  # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
  # https://discord.com/developers/docs/resources/guild#batch-modify-guild-role
  # @param icon [:undef, File]
  def update_role(token, server_id, role_id, name, colour, hoist = false, mentionable = false, packed_permissions = 104_324_161, reason = nil, icon = :undef, unicode_emoji = :undef, colours = :undef)
    data = { color: colour, name: name, hoist: hoist, mentionable: mentionable, permissions: packed_permissions, colors: colours, unicode_emoji: unicode_emoji }

    if icon != :undef && icon
      data[:icon] = OnyxCord.encode64(icon)
    elsif icon.nil?
      data[:icon] = nil
    end

    OnyxCord::REST.request(
      :guilds_sid_roles_rid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles/#{role_id}",
      data.reject { |_, value| value == :undef }.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Modify the properties of a role.
  # https://docs.discord.com/developers/resources/guild#modify-guild-role
  def update_role!(token, server_id, role_id, name: :undef, permissions: :undef, colors: :undef, hoist: :undef, icon: :undef, unicode_emoji: :undef, mentionable: :undef, reason: nil)
    OnyxCord::REST.request(
      :guilds_sid_roles_rid,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles/#{role_id}",
      { name:, permissions:, colors:, hoist:, icon:, unicode_emoji:, mentionable: }.reject { |_, value| value == :undef }.to_json,
      content_type: :json,
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Update role positions
  # https://discord.com/developers/docs/resources/guild#modify-guild-role-positions
  def update_role_positions(token, server_id, roles, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_roles,
      server_id,
      :patch,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles",
      roles.to_json,
      Authorization: token,
      content_type: :json,
      'X-Audit-Log-Reason': reason
    )
  end

  # Delete a role
  # https://discord.com/developers/docs/resources/guild#delete-guild-role
  def delete_role(token, server_id, role_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_roles_rid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles/#{role_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Adds a single role to a member
  # https://discord.com/developers/docs/resources/guild#add-guild-member-role
  def add_member_role(token, server_id, user_id, role_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_members_uid_roles_rid,
      server_id,
      :put,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
      nil,
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Removes a single role from a member
  # https://discord.com/developers/docs/resources/guild#remove-guild-member-role
  def remove_member_role(token, server_id, user_id, role_id, reason = nil)
    OnyxCord::REST.request(
      :guilds_sid_members_uid_roles_rid,
      server_id,
      :delete,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Get the amount of members who have a role
  # https://discord.com/developers/docs/resources/guild#get-guild-roles-members-count
  def role_member_counts(token, server_id)
    OnyxCord::REST.request(
      :guilds_sid_roles_member_counts,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/roles/member-counts",
      Authorization: token
    )
  end
end
