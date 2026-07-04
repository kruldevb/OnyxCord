# frozen_string_literal: true

require 'onyxcord/events/member/base'

module OnyxCord::Events
  # Member joins
  # @see OnyxCord::EventContainer#member_join
  class ServerMemberAddEvent < ServerMemberEvent; end

  # Event handler for {ServerMemberAddEvent}
  class ServerMemberAddEventHandler < ServerMemberEventHandler; end
end
