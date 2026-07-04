# frozen_string_literal: true

require 'onyxcord/events/poll/base'

module OnyxCord::Events
  # Raised whenever someone removes a poll vote.
  class PollVoteRemoveEvent < PollVoteEvent; end

  # Event handler for the :MESSAGE_POLL_VOTE_REMOVE event.
  class PollVoteRemoveEventHandler < PollVoteEventHandler; end
end
