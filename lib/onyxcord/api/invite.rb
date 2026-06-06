# frozen_string_literal: true

# API calls for Invite object
module OnyxCord::API::Invite
  module_function

  # Resolve an invite
  # https://discord.com/developers/docs/resources/invite#get-invite
  def resolve(token, invite_code, counts = true)
    OnyxCord::API.request(
      :invite_code,
      nil,
      :get,
      "#{OnyxCord::API.api_base}/invites/#{invite_code}#{'?with_counts=true' if counts}",
      Authorization: token
    )
  end

  # Delete an invite by code
  # https://discord.com/developers/docs/resources/invite#delete-invite
  def delete(token, code, reason = nil)
    OnyxCord::API.request(
      :invites_code,
      nil,
      :delete,
      "#{OnyxCord::API.api_base}/invites/#{code}",
      Authorization: token,
      'X-Audit-Log-Reason': reason
    )
  end

  # Join a server using an invite
  # https://discord.com/developers/docs/resources/invite#accept-invite
  def accept(token, invite_code)
    OnyxCord::API.request(
      :invite_code,
      nil,
      :post,
      "#{OnyxCord::API.api_base}/invites/#{invite_code}",
      nil,
      Authorization: token
    )
  end
end
