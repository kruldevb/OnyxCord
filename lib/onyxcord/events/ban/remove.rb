# frozen_string_literal: true

require 'onyxcord/events/ban/base'

module OnyxCord::Events
  # Raised when a user is unbanned from a server
  class UserUnbanEvent < UserBanEvent; end

  # Event handler for {UserUnbanEvent}
  class UserUnbanEventHandler < UserBanEventHandler; end
end
