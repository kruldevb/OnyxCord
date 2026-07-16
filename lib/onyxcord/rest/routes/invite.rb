# frozen_string_literal: true

# API calls for Invite object
module OnyxCord::REST::Invite
  module_function

  # Resolve an invite
  # https://discord.com/developers/docs/resources/invite#get-invite
  def resolve(token, invite_code, counts = true)
    code = URI.encode_www_form_component(invite_code.to_s)
    query = URI.encode_www_form({ with_counts: counts ? 'true' : nil }.compact)
    OnyxCord::REST.request(
      :invites_code,
      nil,
      :get,
      "#{OnyxCord::REST.api_base}/invites/#{code}#{"?#{query}" unless query.empty?}",
      headers: { Authorization: token }
    )
  end

  # Delete an invite by code
  # https://discord.com/developers/docs/resources/invite#delete-invite
  def delete(token, code, reason = nil)
    encoded = URI.encode_www_form_component(code.to_s)
    OnyxCord::REST.request(
      :invites_code,
      nil,
      :delete,
      "#{OnyxCord::REST.api_base}/invites/#{encoded}",
      headers: { Authorization: token, 'X-Audit-Log-Reason': reason }
    )
  end

  # @deprecated Bots cannot accept invites via REST. Use OAuth2 authorization URL instead.
  def accept(_token, _invite_code)
    raise NotImplementedError,
          'Invite.accept is no longer supported. Bots are added via OAuth2 authorization URL: ' \
          'https://discord.com/developers/docs/topics/oauth2#bot-authorization-flow'
  end
end
