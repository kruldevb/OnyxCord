# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Make an member avatar URL from the server, user and avatar IDs
  def avatar_url(server_id, user_id, avatar_id, format = nil)
    format ||= if avatar_id.start_with?('a_')
                 'gif'
               else
                 'webp'
               end
    "#{OnyxCord::REST.cdn_url}/guilds/#{server_id}/users/#{user_id}/avatars/#{avatar_id}.#{format}"
  end

  # Make a banner URL from the server, user and banner IDs
  def banner_url(server_id, user_id, banner_id, format = nil)
    format ||= if banner_id.start_with?('a_')
                 'gif'
               else
                 'webp'
               end
    "#{OnyxCord::REST.cdn_url}/guilds/#{server_id}/users/#{user_id}/banners/#{banner_id}.#{format}"
  end
end
