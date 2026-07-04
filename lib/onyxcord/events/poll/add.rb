# frozen_string_literal: true

require 'onyxcord/events/poll/base'

module OnyxCord::Events
  # Raised whenever someone votes on a poll.
  class PollVoteAddEvent < PollVoteEvent; end

  # Event handler for the :MESSAGE_POLL_VOTE_ADD event.
  class PollVoteAddEventHandler < PollVoteEventHandler; end
end
