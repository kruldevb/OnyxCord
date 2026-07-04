# frozen_string_literal: true

require 'onyxcord/events/member/base'

module OnyxCord::Events
  # Member is updated (roles added or deleted)
  # @see OnyxCord::EventContainer#member_update
  class ServerMemberUpdateEvent < ServerMemberEvent
    # @!visibility private
    # @note Override init_user so we don't make requests all the time on large servers
    def init_user(data, _)
      @user_id = data['user']['id']
    end

    # @return [Member] the member in question.
    def user
      @server&.member(@user_id)
    end

    alias_method :member, :user
  end

  # Event handler for {ServerMemberUpdateEvent}
  class ServerMemberUpdateEventHandler < ServerMemberEventHandler; end
end
