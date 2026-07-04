# frozen_string_literal: true

# API calls for Invite object
module OnyxCord::REST::Invite
  module_function

  # Resolve an invite
  # https://discord.com/developers/docs/resources/invite#get-invite
  def resolve(token, invite_code, counts = true)
    OnyxCord::REST.request(
      :invite_code,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/invites/#{invite_code}#{'?with_counts=true' if counts}",
      Authorization: token
    )
  end

  # Delete an invite by code
  # https://discord.com/developers/docs/resources/invite#delete-invite
  def delete(token, code, reason = nil)
    OnyxCord::REST.request(
      :invites_code,
      nil,
      :delete,
      "#{OnyxCord::REST.api_base}/invites/#{code}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Join a server using an invite
  # https://discord.com/developers/docs/resources/invite#accept-invite
  def accept(token, invite_code)
    OnyxCord::REST.request(
      :invite_code,
      nil,
      :post,
      "#{OnyxCord::REST.api_base}/invites/#{invite_code}",
      nil,
      Authorization: token
    )
  end
end
