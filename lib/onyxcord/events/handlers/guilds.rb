# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised when a new user joins a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the joined user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberAddEvent] The event that was raised.
    # @return [ServerMemberAddEventHandler] the event handler that was registered.
    def member_join(attributes = {}, &block)
      register_event(ServerMemberAddEvent, attributes, block)
    end

    # This **event** is raised when a member update happens. This includes when a members nickname
    # or roles are updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the updated user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberUpdateEvent] The event that was raised.
    # @return [ServerMemberUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when a member update happens. This includes when a members nickname
    # or roles are updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the updated user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberUpdateEvent] The event that was raised.
    # @return [ServerMemberUpdateEventHandler] the event handler that was registered.
    def member_update(attributes = {}, &block)
      register_event(ServerMemberUpdateEvent, attributes, block)
    end

    # This **event** is raised when a member leaves a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the member.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberDeleteEvent] The event that was raised.
    # @return [ServerMemberDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when a member leaves a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the member.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberDeleteEvent] The event that was raised.
    # @return [ServerMemberDeleteEventHandler] the event handler that was registered.
    def member_leave(attributes = {}, &block)
      register_event(ServerMemberDeleteEvent, attributes, block)
    end

    # This **event** is raised when a user is banned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was banned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was banned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserBanEvent] The event that was raised.
    # @return [UserBanEventHandler] the event handler that was registered.

    # This **event** is raised when a user is banned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was banned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was banned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserBanEvent] The event that was raised.
    # @return [UserBanEventHandler] the event handler that was registered.
    def user_ban(attributes = {}, &block)
      register_event(UserBanEvent, attributes, block)
    end

    # This **event** is raised whenever an audit log entry is created in a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server the entry was created in.
    # @option attributes [String, Symbol, Integer] :action Matches the type of the entry.
    # @option attributes [String, Regexp] :reason Matches the reason associated with the entry.
    # @option attributes [String, Integer, User, Member, Recipient] :user Matches the user or bot that made the changes.
    # @option attributes [String, Integer, #resolve_id] :target Matches the ID of the affected entity.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AuditLogEntryCreateEvent] The event that was raised.
    # @return [AuditLogEntryCreateEventHandler] the event handler that was registered.

    # This **event** is raised whenever an audit log entry is created in a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server the entry was created in.
    # @option attributes [String, Symbol, Integer] :action Matches the type of the entry.
    # @option attributes [String, Regexp] :reason Matches the reason associated with the entry.
    # @option attributes [String, Integer, User, Member, Recipient] :user Matches the user or bot that made the changes.
    # @option attributes [String, Integer, #resolve_id] :target Matches the ID of the affected entity.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AuditLogEntryCreateEvent] The event that was raised.
    # @return [AuditLogEntryCreateEventHandler] the event handler that was registered.
    def audit_log_entry(attributes = {}, &block)
      register_event(AuditLogEntryCreateEvent, attributes, block)
    end

    # This **event** is raised when a user is unbanned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was unbanned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was unbanned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserUnbanEvent] The event that was raised.
    # @return [UserUnbanEventHandler] the event handler that was registered.

    # This **event** is raised when a user is unbanned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was unbanned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was unbanned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserUnbanEvent] The event that was raised.
    # @return [UserUnbanEventHandler] the event handler that was registered.
    def user_unban(attributes = {}, &block)
      register_event(UserUnbanEvent, attributes, block)
    end

    # This **event** is raised when a server is created respective to the bot, i.e. the bot joins a server or creates
    # a new one itself.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was created.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerCreateEvent] The event that was raised.
    # @return [ServerCreateEventHandler] the event handler that was registered.

    # This **event** is raised when a server is created respective to the bot, i.e. the bot joins a server or creates
    # a new one itself.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was created.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerCreateEvent] The event that was raised.
    # @return [ServerCreateEventHandler] the event handler that was registered.
    def server_create(attributes = {}, &block)
      register_event(ServerCreateEvent, attributes, block)
    end

    # This **event** is raised when a server is updated, for example if the name or region has changed.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was updated.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerUpdateEvent] The event that was raised.
    # @return [ServerUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when a server is updated, for example if the name or region has changed.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was updated.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerUpdateEvent] The event that was raised.
    # @return [ServerUpdateEventHandler] the event handler that was registered.
    def server_update(attributes = {}, &block)
      register_event(ServerUpdateEvent, attributes, block)
    end

    # This **event** is raised when a server is deleted, or when the bot leaves a server. (These two cases are identical
    # to Discord.)
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was deleted.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerDeleteEvent] The event that was raised.
    # @return [ServerDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when a server is deleted, or when the bot leaves a server. (These two cases are identical
    # to Discord.)
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was deleted.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerDeleteEvent] The event that was raised.
    # @return [ServerDeleteEventHandler] the event handler that was registered.
    def server_delete(attributes = {}, &block)
      register_event(ServerDeleteEvent, attributes, block)
    end

    # This **event** is raised when an emoji or collection of emojis is created/deleted/updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiChangeEvent] The event that was raised.
    # @return [ServerEmojiChangeEventHandler] the event handler that was registered.

    # This **event** is raised when an emoji or collection of emojis is created/deleted/updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiChangeEvent] The event that was raised.
    # @return [ServerEmojiChangeEventHandler] the event handler that was registered.
    def server_emoji(attributes = {}, &block)
      register_event(ServerEmojiChangeEvent, attributes, block)
    end

    # This **event** is raised when an emoji is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the ID of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiCreateEvent] The event that was raised.
    # @return [ServerEmojiCreateEventHandler] the event handler that was registered.

    # This **event** is raised when an emoji is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the ID of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiCreateEvent] The event that was raised.
    # @return [ServerEmojiCreateEventHandler] the event handler that was registered.
    def server_emoji_create(attributes = {}, &block)
      register_event(ServerEmojiCreateEvent, attributes, block)
    end

    # This **event** is raised when an emoji is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the ID of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiDeleteEvent] The event that was raised.
    # @return [ServerEmojiDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when an emoji is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the ID of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiDeleteEvent] The event that was raised.
    # @return [ServerEmojiDeleteEventHandler] the event handler that was registered.
    def server_emoji_delete(attributes = {}, &block)
      register_event(ServerEmojiDeleteEvent, attributes, block)
    end

    # This **event** is raised when an emoji is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the ID of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @option attributes [String] :old_name Matches the name of the emoji before the update.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiUpdateEvent] The event that was raised.
    # @return [ServerEmojiUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when an emoji is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the ID of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @option attributes [String] :old_name Matches the name of the emoji before the update.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiUpdateEvent] The event that was raised.
    # @return [ServerEmojiUpdateEventHandler] the event handler that was registered.
    def server_emoji_update(attributes = {}, &block)
      register_event(ServerEmojiUpdateEvent, attributes, block)
    end

    # This **event** is raised when a role is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the role name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerRoleCreateEvent] The event that was raised.
    # @return [ServerRoleCreateEventHandler] the event handler that was registered.

    # This **event** is raised when a role is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the role name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerRoleCreateEvent] The event that was raised.
    # @return [ServerRoleCreateEventHandler] the event handler that was registered.
    def server_role_create(attributes = {}, &block)
      register_event(ServerRoleCreateEvent, attributes, block)
    end

    # This **event** is raised when a role is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the role ID.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerRoleDeleteEvent] The event that was raised.
    # @return [ServerRoleDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when a role is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :id Matches the role ID.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerRoleDeleteEvent] The event that was raised.
    # @return [ServerRoleDeleteEventHandler] the event handler that was registered.
    def server_role_delete(attributes = {}, &block)
      register_event(ServerRoleDeleteEvent, attributes, block)
    end

    # This **event** is raised when a role is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the role name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerRoleUpdateEvent] The event that was raised.
    # @return [ServerRoleUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when a role is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the role name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerRoleUpdateEvent] The event that was raised.
    # @return [ServerRoleUpdateEventHandler] the event handler that was registered.
    def server_role_update(attributes = {}, &block)
      register_event(ServerRoleUpdateEvent, attributes, block)
    end

    # This **event** is raised when a webhook is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server by name, ID or instance.
    # @option attributes [String, Integer, Channel] :channel Matches the channel by name, ID or instance.
    # @option attribute [String, Integer, Webhook] :webhook Matches the webhook by name, ID or instance.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [WebhookUpdateEvent] The event that was raised.
    # @return [WebhookUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when a webhook is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server by name, ID or instance.
    # @option attributes [String, Integer, Channel] :channel Matches the channel by name, ID or instance.
    # @option attribute [String, Integer, Webhook] :webhook Matches the webhook by name, ID or instance.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [WebhookUpdateEvent] The event that was raised.
    # @return [WebhookUpdateEventHandler] the event handler that was registered.
    def webhook_update(attributes = {}, &block)
      register_event(WebhookUpdateEvent, attributes, block)
    end

    # This **event** is raised when an {Await} is triggered. It provides an easy way to execute code
    # on an await without having to rely on the await's block.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Symbol] :key Exactly matches the await's key.
    # @option attributes [Class] :type Exactly matches the event's type.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AwaitEvent] The event that was raised.
    # @return [AwaitEventHandler] the event handler that was registered.

    # This **event** is raised when an invite is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :inviter Matches the user that created the invite.
    # @option attributes [String, Integer, Channel] :channel Matches the channel the invite was created for.
    # @option attributes [String, Integer, Server] :server Matches the server the invite was created for.
    # @option attributes [true, false] :temporary Matches whether the invite is temporary or not.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [InviteCreateEvent] The event that was raised.
    # @return [InviteCreateEventHandler] The event handler that was registered.
    def invite_create(attributes = {}, &block)
      register_event(InviteCreateEvent, attributes, block)
    end

    # This **event** is raised when an invite is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :channel Matches the channel the deleted invite was for.
    # @option attributes [String, Integer, Server] :server Matches the server the deleted invite was for.
    # @yield The block is executed when the event is raised
    # @yieldparam event [InviteDeleteEvent] The event that was raised.
    # @return [InviteDeleteEventHandler] The event handler that was registered.

    # This **event** is raised when an invite is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :channel Matches the channel the deleted invite was for.
    # @option attributes [String, Integer, Server] :server Matches the server the deleted invite was for.
    # @yield The block is executed when the event is raised
    # @yieldparam event [InviteDeleteEvent] The event that was raised.
    # @return [InviteDeleteEventHandler] The event handler that was registered.
    def invite_delete(attributes = {}, &block)
      register_event(InviteDeleteEvent, attributes, block)
    end

    # This **event** is raised whenever an interaction event is received.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer, Symbol, String] :type The interaction type, can be the integer value or the name
    #   of the key in {OnyxCord::Interaction::TYPES}.
    # @option attributes [String, Integer, Server, nil] :server The server where this event was created. `nil` for DM channels.
    # @option attributes [String, Integer, Channel] :channel The channel where this event was created.
    # @option attributes [String, Integer, User] :user The user that triggered this event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [InteractionCreateEvent] The event that was raised.
    # @return [InteractionCreateEventHandler] The event handler that was registered.
  end
end
