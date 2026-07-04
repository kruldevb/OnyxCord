# frozen_string_literal: true

module OnyxCord
  module Internal
    module EventBus
      include Events

      def handle_dispatch(type, data)
        # Check whether there are still unavailable servers and there have been more than 10 seconds since READY
        if @unavailable_servers&.positive? && (Time.now - @unavailable_timeout_time) > 10 && !(@intents || 0).nobits?(INTENTS[:servers])
          # The server streaming timed out!
          LOGGER.debug("Server streaming timed out with #{@unavailable_servers} servers remaining")
          LOGGER.debug('Calling ready now because server loading is taking a long time. Servers may be unavailable due to an outage, or your bot is on very large servers.')

          # Unset the unavailable server count so this doesn't get triggered again
          @unavailable_servers = 0

          notify_ready
        end

        case type
        when :READY
          # As READY may be called multiple times over a single process lifetime, we here need to reset the cache entirely
          # to prevent possible inconsistencies, like objects referencing old versions of other objects which have been
          # replaced.
          init_cache

          @profile = Profile.new(data['user'], self)

          @client_id ||= data['application']['id']&.to_i

          # Initialize servers
          @servers = {}

          # Count unavailable servers
          @unavailable_servers = 0

          data['guilds'].each do |element|
            # Check for true specifically because unavailable=false indicates that a previously unavailable server has
            # come online
            if element['unavailable']
              @unavailable_servers += 1

              # Ignore any unavailable servers
              next
            end

            ensure_server(element, true)
          end

          # Don't notify yet if there are unavailable servers because they need to get available before the bot truly has
          # all the data
          if @unavailable_servers.zero?
            # No unavailable servers - we're ready!
            notify_ready
          end

          @ready_time = Time.now
          @unavailable_timeout_time = Time.now
        when :GUILD_MEMBERS_CHUNK
          id = data['guild_id'].to_i
          server = server(id)
          server.process_chunk(data['members'], data['chunk_index'], data['chunk_count'])
        when :USER_UPDATE
          @profile = Profile.new(data, self)
        when :INVITE_CREATE
          invite = Invite.new(data, self)
          raise_event(InviteCreateEvent.new(data, invite, self))
        when :INVITE_DELETE
          raise_event(InviteDeleteEvent.new(data, self))
        when :MESSAGE_CREATE
          if ignored?(data['author']['id'])
            debug("Ignored author with ID #{data['author']['id']}")
            return
          end

          if @ignore_bots && data['author']['bot']
            debug("Ignored Bot account with ID #{data['author']['id']}")
            return
          end

          if !should_parse_self && profile.id == data['author']['id'].to_i
            debug('Ignored message from the current bot')
            return
          end

          # If create_message is overwritten with a method that returns the parsed message, use that instead, so we don't
          # parse the message twice (which is just thrown away performance)
          message = create_message(data)
          message = Message.new(data, self) unless message.is_a? Message

          # Update the existing member if it exists in the cache.
          if data['member']
            member = message.channel.server&.member(data['author']['id'].to_i, false)
            data['member']['user'] = data['author']
            member&.update_data(data['member'])
          end

          # Dispatch a ChannelCreateEvent for channels we don't have cached
          if message.channel.private? && !@pm_channels&.key?(message.channel.recipient.id)
            create_channel(message.channel)

            raise_event(ChannelCreateEvent.new(message.channel, self))
          end

          message.channel.process_last_message_id(message.id)

          event = MessageEvent.new(message, self)
          raise_event(event)

          # Raise a mention event for any direct mentions.
          if message.mentions.any? { |user| user.id == profile.id }
            event = MentionEvent.new(message, self, false)
            raise_event(event)
          end

          # Raise a mention event for the current bot's auto-generated role.
          if message.role_mentions.any? { |role| role.tags&.bot_id == profile.id }
            event = MentionEvent.new(message, self, true)
            raise_event(event)
          end

          if message.channel.private?
            event = PrivateMessageEvent.new(message, self)
            raise_event(event)
          end
        when :MESSAGE_UPDATE
          update_message(data)

          if !should_parse_self && profile.id == data['author']['id'].to_i
            debug('Ignored message from the current bot')
            return
          end

          message = Message.new(data, self)

          event = MessageUpdateEvent.new(message, self)
          raise_event(event)

          if data['author'].nil?
            LOGGER.debug("Edited a message with nil author! Content: #{message.content.inspect}, channel: #{message.channel.inspect}")
            return
          end

          # Update the existing member if it exists in the cache.
          if data['member']
            member = message.channel.server&.member(data['author']['id'].to_i, false)
            data['member']['user'] = data['author']
            member&.update_data(data['member'])
          end

          event = MessageEditEvent.new(message, self)
          raise_event(event)
        when :MESSAGE_DELETE
          delete_message(data)

          event = MessageDeleteEvent.new(data, self)
          raise_event(event)
        when :MESSAGE_DELETE_BULK
          debug("MESSAGE_DELETE_BULK will raise #{data['ids'].length} events")

          data['ids'].each do |single_id|
            # Form a data hash for a single ID so the methods get what they want
            single_data = {
              'id' => single_id,
              'channel_id' => data['channel_id']
            }

            # Raise as normal
            delete_message(single_data)

            event = MessageDeleteEvent.new(single_data, self)
            raise_event(event)
          end
        when :TYPING_START
          start_typing(data)

          begin
            event = TypingEvent.new(data, self)
            raise_event(event)
          rescue OnyxCord::Errors::NoPermission
            debug 'Typing started in channel the bot has no access to, ignoring'
          end
        when :MESSAGE_REACTION_ADD
          add_message_reaction(data)

          return if profile.id == data['user_id'].to_i && !should_parse_self

          if data['member']
            server = self.server(data['guild_id'].to_i)

            server&.cache_member(Member.new(data['member'], server, self))
          end

          event = ReactionAddEvent.new(data, self)
          raise_event(event)
        when :MESSAGE_REACTION_REMOVE
          remove_message_reaction(data)

          return if profile.id == data['user_id'].to_i && !should_parse_self

          event = ReactionRemoveEvent.new(data, self)
          raise_event(event)
        when :MESSAGE_REACTION_REMOVE_ALL
          remove_all_message_reactions(data)

          event = ReactionRemoveAllEvent.new(data, self)
          raise_event(event)
        when :MESSAGE_REACTION_REMOVE_EMOJI

          event = ReactionRemoveEmojiEvent.new(data, self)
          raise_event(event)
        when :PRESENCE_UPDATE
          # Ignore friends list presences
          return unless data['guild_id']

          new_activities = (data['activities'] || []).map { |act_data| Activity.new(act_data, self) }
          presence_user = @users[data['user']['id'].to_i]
          old_activities = (presence_user&.activities || [])
          update_presence(data)

          # Starting a new game
          playing_change = new_activities.reject do |act|
            old_activities.find { |old| old.name == act.name }
          end

          # Exiting an existing game
          playing_change += old_activities.reject do |old|
            new_activities.find { |act| act.name == old.name }
          end

          if playing_change.any?
            playing_change.each do |act|
              raise_event(PlayingEvent.new(data, act, self))
            end
          else
            raise_event(PresenceEvent.new(data, self))
          end
        when :VOICE_STATE_UPDATE
          old_channel_id = update_voice_state(data)

          event = VoiceStateUpdateEvent.new(data, old_channel_id, self)
          raise_event(event)
        when :VOICE_SERVER_UPDATE
          update_voice_server(data)

          event = VoiceServerUpdateEvent.new(data, self)
          raise_event(event)
        when :CHANNEL_CREATE
          create_channel(data)

          event = ChannelCreateEvent.new(data, self)
          raise_event(event)
        when :CHANNEL_UPDATE
          update_channel(data)

          event = ChannelUpdateEvent.new(data, self)
          raise_event(event)
        when :CHANNEL_DELETE
          delete_channel(data)

          event = ChannelDeleteEvent.new(data, self)
          raise_event(event)
        when :CHANNEL_PINS_UPDATE
          event = ChannelPinsUpdateEvent.new(data, self)

          event.channel.process_last_pin_timestamp(data['last_pin_timestamp']) if data.key?('last_pin_timestamp')

          raise_event(event)
        when :GUILD_MEMBER_ADD
          add_guild_member(data)

          event = ServerMemberAddEvent.new(data, self)
          raise_event(event)
        when :GUILD_MEMBER_UPDATE
          update_guild_member(data)

          event = ServerMemberUpdateEvent.new(data, self)
          raise_event(event)
        when :GUILD_MEMBER_REMOVE
          delete_guild_member(data)

          event = ServerMemberDeleteEvent.new(data, self)
          raise_event(event)
        when :GUILD_AUDIT_LOG_ENTRY_CREATE
          event = AuditLogEntryCreateEvent.new(data, self)
          raise_event(event)
        when :GUILD_BAN_ADD
          add_user_ban(data)

          event = UserBanEvent.new(data, self)
          raise_event(event)
        when :GUILD_BAN_REMOVE
          remove_user_ban(data)

          event = UserUnbanEvent.new(data, self)
          raise_event(event)
        when :GUILD_ROLE_UPDATE
          update_guild_role(data)

          event = ServerRoleUpdateEvent.new(data, self)
          raise_event(event)
        when :GUILD_ROLE_CREATE
          update_guild_role(data)

          event = ServerRoleCreateEvent.new(data, self)
          raise_event(event)
        when :GUILD_ROLE_DELETE
          delete_guild_role(data)

          event = ServerRoleDeleteEvent.new(data, self)
          raise_event(event)
        when :INTEGRATION_CREATE
          event = IntegrationCreateEvent.new(data, self)
          raise_event(event)
        when :INTEGRATION_UPDATE
          event = IntegrationUpdateEvent.new(data, self)
          raise_event(event)
        when :INTEGRATION_DELETE
          event = IntegrationDeleteEvent.new(data, self)
          raise_event(event)
        when :GUILD_CREATE
          create_guild(data)

          # Check for false specifically (no data means the server has never been unavailable)
          if data['unavailable'].is_a? FalseClass
            @unavailable_servers -= 1 if @unavailable_servers
            @unavailable_timeout_time = Time.now

            notify_ready if @unavailable_servers.zero?

            # Return here so the event doesn't get triggered
            return
          end

          event = ServerCreateEvent.new(data, self)
          raise_event(event)
        when :GUILD_UPDATE
          update_guild(data)

          event = ServerUpdateEvent.new(data, self)
          raise_event(event)
        when :GUILD_DELETE
          delete_guild(data)

          if data['unavailable'].is_a? TrueClass
            LOGGER.warn("Server #{data['id']} is unavailable due to an outage!")
            return # Don't raise an event
          end

          event = ServerDeleteEvent.new(data, self)
          raise_event(event)
        when :GUILD_EMOJIS_UPDATE
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          old_emoji_data = server.emoji.clone
          update_guild_emoji(data)
          new_emoji_data = server.emoji

          created_ids = new_emoji_data.keys - old_emoji_data.keys
          deleted_ids = old_emoji_data.keys - new_emoji_data.keys
          updated_ids = old_emoji_data.select do |k, v|
            new_emoji_data[k] && (v.name != new_emoji_data[k].name || v.roles != new_emoji_data[k].roles)
          end.keys

          event = ServerEmojiChangeEvent.new(server, data, self)
          raise_event(event)

          created_ids.each do |e|
            event = ServerEmojiCreateEvent.new(server, new_emoji_data[e], self)
            raise_event(event)
          end

          deleted_ids.each do |e|
            event = ServerEmojiDeleteEvent.new(server, old_emoji_data[e], self)
            raise_event(event)
          end

          updated_ids.each do |e|
            event = ServerEmojiUpdateEvent.new(server, old_emoji_data[e], new_emoji_data[e], self)
            raise_event(event)
          end
        when :APPLICATION_COMMAND_PERMISSIONS_UPDATE
          event = ApplicationCommandPermissionsUpdateEvent.new(data, self)

          raise_event(event)
        when :INTERACTION_CREATE
          event = InteractionCreateEvent.new(data, self)
          raise_event(event)

          case data['type']
          when Interaction::TYPES[:command]
            event = ApplicationCommandEvent.new(data, self)

            @event_executor.post do
              Thread.current[:onyxcord_name] = next_event_thread_name('it')
              handler = @application_commands[event.command_name]
              handler&.call(event)
            rescue StandardError => e
              log_exception(e)
            end
          when Interaction::TYPES[:component]
            case data['data']['component_type']
            when Webhooks::View::COMPONENT_TYPES[:button]
              event = ButtonEvent.new(data, self)

              raise_event(event)
            when Webhooks::View::COMPONENT_TYPES[:string_select]
              event = StringSelectEvent.new(data, self)

              raise_event(event)
            when Webhooks::View::COMPONENT_TYPES[:user_select]
              event = UserSelectEvent.new(data, self)

              raise_event(event)
            when Webhooks::View::COMPONENT_TYPES[:role_select]
              event = RoleSelectEvent.new(data, self)

              raise_event(event)
            when Webhooks::View::COMPONENT_TYPES[:mentionable_select]
              event = MentionableSelectEvent.new(data, self)

              raise_event(event)
            when Webhooks::View::COMPONENT_TYPES[:channel_select]
              event = ChannelSelectEvent.new(data, self)

              raise_event(event)
            end
          when Interaction::TYPES[:modal_submit]

            event = ModalSubmitEvent.new(data, self)
            raise_event(event)
          when Interaction::TYPES[:autocomplete]

            event = AutocompleteEvent.new(data, self)
            raise_event(event)
          end
        when :WEBHOOKS_UPDATE
          event = WebhookUpdateEvent.new(data, self)
          raise_event(event)
        when :THREAD_CREATE
          create_channel(data)

          event = ThreadCreateEvent.new(data, self)
          raise_event(event)
        when :THREAD_UPDATE
          update_channel(data)

          event = ThreadUpdateEvent.new(data, self)
          raise_event(event)
        when :THREAD_DELETE
          delete_channel(data)
          @thread_members.delete(data['id']&.resolve_id)

          # raise ThreadDeleteEvent
        when :THREAD_LIST_SYNC
          server_id = data['guild_id'].to_i
          server = @servers[server_id]

          # The `channel_ids` field has two meanings:
          #
          # 1. If the field is not present, the thread list is being synced for the whole server.
          #
          # 2. We are syncing the threads for a specific channel. This can happen when gaining access
          #    to a channel.
          if (ids = data['channel_ids']&.map(&:to_i))
            @channels.delete_if { |_, channel| channel.thread? && ids.any?(channel.parent&.id) }
            server&.clear_threads(ids)
          else
            @channels.delete_if { |_, channel| channel.server.id == server_id && channel.thread? }
            server&.clear_threads
          end

          data['members'].each { |member| ensure_thread_member(member) }
          data['threads'].each { |channel| ensure_channel(channel) }

          # raise ThreadListSyncEvent?
        when :THREAD_MEMBER_UPDATE
          ensure_thread_member(data)
        when :THREAD_MEMBERS_UPDATE
          data['added_members']&.each do |added_member|
            ensure_thread_member(added_member) if added_member['user_id']
          end

          data['removed_member_ids']&.each do |member_id|
            @thread_members[data['id']&.resolve_id]&.delete(member_id&.resolve_id)
          end

          event = ThreadMembersUpdateEvent.new(data, self)
          raise_event(event)
        when :MESSAGE_POLL_VOTE_ADD
          event = PollVoteAddEvent.new(data, self)
          raise_event(event)
        when :MESSAGE_POLL_VOTE_REMOVE
          event = PollVoteRemoveEvent.new(data, self)
          raise_event(event)
        when :GUILD_SCHEDULED_EVENT_CREATE
          update_guild_scheduled_event(data)

          event = ScheduledEventCreateEvent.new(data, self)
          raise_event(event)
        when :GUILD_SCHEDULED_EVENT_UPDATE
          update_guild_scheduled_event(data)

          event = ScheduledEventUpdateEvent.new(data, self)
          raise_event(event)
        when :GUILD_SCHEDULED_EVENT_DELETE
          @servers[data['guild_id'].to_i]&.delete_scheduled_event(data['id'].to_i)

          event = ScheduledEventDeleteEvent.new(data, self)
          raise_event(event)
        when :GUILD_SCHEDULED_EVENT_USER_ADD
          server = @servers[data['guild_id'].to_i]
          server&.scheduled_event(data['guild_scheduled_event_id'], request: false)&.increment_user_count

          event = ScheduledEventUserAddEvent.new(data, self)
          raise_event(event)
        when :GUILD_SCHEDULED_EVENT_USER_REMOVE
          server = @servers[data['guild_id'].to_i]
          server&.scheduled_event(data['guild_scheduled_event_id'], request: false)&.deincrement_user_count

          event = ScheduledEventUserRemoveEvent.new(data, self)
          raise_event(event)
        else
          # another event that we don't support yet
          debug "Event #{type} has been received but is unsupported. Raising UnknownEvent"

          event = UnknownEvent.new(type, data, self)
          raise_event(event)
        end

        # The existence of this array is checked before for performance reasons, since this has to be done for *every*
        # dispatch.
        if @event_handlers && @event_handlers[RawEvent]
          event = RawEvent.new(type, data, self)
          raise_event(event)
        end
      rescue Exception => e
        if defined?(Async::Cancel) && e.is_a?(Async::Cancel)
          LOGGER.debug('Gateway message handling was cancelled.')
          return
        end

        LOGGER.error('Gateway message error!')
        log_exception(e)
      end

      def dispatch_packet(packet)
        type = packet['t']&.intern
        data = packet['d']

        case @mode
        when :raw
          dispatch_raw_packet(packet)
          notify_raw_ready if type == :READY
        when :hybrid
          dispatch_raw_packet(packet)
          handle_dispatch(type, data)
        else
          handle_dispatch(type, data)
        end
      end

      def dispatch_raw_packet(packet)
        handlers = @raw_handlers
        return unless handlers

        handlers.dup.each do |handler|
          call_raw_handler(handler, packet) if handler.matches?(packet)
        end
      end

      def call_raw_handler(handler, packet)
        @event_executor.post do
          Thread.current[:onyxcord_name] = next_event_thread_name('rt')
          handler.call(packet)
        rescue StandardError => e
          log_exception(e)
        end
      end

      def notify_raw_ready
        return if @raw_ready_notified

        @raw_ready_notified = true
        LOGGER.good 'Ready'
        @gateway.notify_ready
      end
    end
  end
end
