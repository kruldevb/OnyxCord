# frozen_string_literal: true

module OnyxCord::REST::Channel
  module_function

  # Get a list of users that have voted for a poll answer.
  # https://discord.com/developers/docs/resources/poll#get-answer-voters
  def get_poll_voters(token, channel_id, message_id, answer_id, limit: 100, after: nil)
    query = URI.encode_www_form({ limit:, after: }.compact)

    OnyxCord::REST.request(
      :channels_cid_polls_mid_answers_aid,
      channel_id,
      :get,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/polls/#{message_id}/answers/#{answer_id}?#{query}",
      Authorization: token
    )
  end

  # End a poll created by the current user.
  # https://discord.com/developers/docs/resources/poll#end-poll
  def end_poll(token, channel_id, message_id)
    OnyxCord::REST.request(
      :channels_cid_polls_mid_expire,
      channel_id,
      :post,
      "#{OnyxCord::REST.api_base}/channels/#{channel_id}/polls/#{message_id}/expire",
      nil,
      Authorization: token
    )
  end
end
