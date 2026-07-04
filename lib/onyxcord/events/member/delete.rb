# frozen_string_literal: true

require 'onyxcord/events/member/base'

module OnyxCord::Events
  # Member leaves
  # @see OnyxCord::EventContainer#member_leave
  class ServerMemberDeleteEvent < ServerMemberEvent
    # @!visibility private
    # @note Override init_user to account for the deleted user on the server
    def init_user(data, bot)
      @user = OnyxCord::User.new(data['user'], bot)
    end

    # @return [User] the user in question.
    attr_reader :user
  end

  # Event handler for {ServerMemberDeleteEvent}
  class ServerMemberDeleteEventHandler < ServerMemberEventHandler; end
end
