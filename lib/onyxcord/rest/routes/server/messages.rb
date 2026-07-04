# frozen_string_literal: true

module OnyxCord::REST::Server
  module_function

  # Query and filter the messages that have been sent in a server.
  # https://discord.com/developers/docs/resources/message#search-guild-messages
  def search_messages(token, server_id, limit: 25, offset: nil, max_id: nil, min_id: nil, slop: nil, content: nil, channel_id: nil, author_type: nil, author_id: nil, mentions: nil, mentions_role_id: nil, mention_everyone: nil, replied_to_user_id: nil, replied_to_message_id: nil, pinned: nil, has: nil, embed_type: nil, embed_provider: nil, link_hostname: nil, attachment_filename: nil, attachment_extension: nil, sort_by: nil, sort_order: nil, include_nsfw: nil)
    query = URI.encode_www_form({ limit:, offset:, max_id:, min_id:, slop:, content:, channel_id:, author_type:, author_id:, mentions:, mentions_role_id:, mention_everyone:, replied_to_user_id:, replied_to_message_id:, pinned:, has:, embed_type:, embed_provider:, link_hostname:, attachment_filename:, attachment_extension:, sort_by:, sort_order:, include_nsfw: }.compact)

    OnyxCord::REST.request(
      :guilds_gid_messages_search,
      server_id,
      :get,
      "#{OnyxCord::REST.api_base}/guilds/#{server_id}/messages/search?#{query}",
      Authorization: token
    )
  end
end
