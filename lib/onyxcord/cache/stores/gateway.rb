# frozen_string_literal: true

module OnyxCord
  module Cache
    module Stores
      module Gateway
        private

        # Internal handler for PRESENCE_UPDATE
        def update_presence(data)
          # Friends list presences have no server ID so ignore these to not cause an error
          return unless data['guild_id']

          user_id = data['user']['id'].to_i
          server_id = data['guild_id'].to_i
          server = server(server_id)
          return unless server

          member_is_new = false

          if server.member_cached?(user_id)
            member = server.member(user_id)
          else
            # If the member is not cached yet, it means that it just came online from not being cached at all
            # due to large_threshold. Fortunately, Discord sends the entire member object in this case, and
            # not just a part of it - we can just cache this member directly
            member = Member.new(data, server, self)
            debug("Implicitly adding presence-obtained member #{user_id} to #{server_id} cache")

            member_is_new = true
          end

          username = data['user']['username']
          if username && !member_is_new # Don't set the username for newly-cached members
            debug "Implicitly updating presence-obtained information username for member #{user_id}"
            member.update_username(username)
          end

          global_name = data['user']['global_name']
          if global_name && !member_is_new # Don't set the global_name for newly-cached members
            debug "Implicitly updating presence-obtained information global_name for member #{user_id}"
            member.update_global_name(global_name)
          end

          member.update_presence(data)

          member.avatar_id = data['user']['avatar'] if data['user']['avatar']

          server.cache_member(member)
        end

        # Internal handler for VOICE_STATE_UPDATE
        def update_voice_state(data)
          @session_id = data['session_id']

          server_id = data['guild_id'].to_i
          server = @servers&.[](server_id)
          return unless server

          user_id = data['user_id'].to_i
          old_voice_state = server.voice_states[user_id]
          old_channel_id = old_voice_state&.channel_id || old_voice_state&.voice_channel&.id

          server.update_voice_state(data)

          existing_voice = @voices[server_id]
          if user_id == @profile.id && existing_voice
            new_channel_id = data['channel_id']
            if new_channel_id
              channel_id = new_channel_id.to_i
              new_channel = @channels&.[](channel_id) || server.channels.find { |channel| channel.id == channel_id }
              existing_voice.channel = new_channel
            else
              voice_destroy(server_id)
            end
          end

          old_channel_id
        end

        # Internal handler for VOICE_SERVER_UPDATE
        def update_voice_server(data)
          server_id = data['guild_id'].to_i
          channel = @should_connect_to_voice[server_id]

          debug("Voice server update received! chan: #{channel.inspect}")
          return unless channel

          @should_connect_to_voice.delete(server_id)
          debug('Updating voice server!')

          token = data['token']
          endpoint = data['endpoint']

          unless endpoint
            debug('VOICE_SERVER_UPDATE sent with nil endpoint! Ignoring')
            return
          end

          debug('Got data, now creating the bot.')
          @voices[server_id] = OnyxCord::Voice::Client.new(channel, self, token, @session_id, endpoint)
        end

        # Internal handler for CHANNEL_CREATE
        def create_channel(data)
          channel = data.is_a?(OnyxCord::Channel) ? data : Channel.new(data, self)
          server = channel.server

          # The last message ID of a forum channel is the most recent post
          channel.parent.process_last_message_id(channel.id) if channel.parent&.forum? || channel.parent&.media?

          # Handle normal and private channels separately
          if server
            server.add_channel(channel)
            @channels[channel.id] = channel if @channels
          elsif channel.private?
            @pm_channels[channel.recipient.id] = channel if @pm_channels
          elsif channel.group?
            @channels[channel.id] = channel if @channels
          end
        end

        # Internal handler for CHANNEL_UPDATE
        def update_channel(data)
          @channels&.[](data['id'].to_i)&.update_data(data)
        end

        # Internal handler for CHANNEL_DELETE
        def delete_channel(data)
          channel = Channel.new(data, self)
          server = channel.server

          # Handle normal and private channels separately
          if server
            @channels&.delete(channel.id)
            server.delete_channel(channel.id)
          elsif channel.pm?
            @pm_channels&.delete(channel.recipient.id)
          elsif channel.group?
            @channels&.delete(channel.id)
          end

          @thread_members&.delete(channel.id) if channel.thread?
        end

        # Internal handler for GUILD_MEMBER_ADD
        def add_guild_member(data)
          server_id = data['guild_id'].to_i
          server = self.server(server_id)

          member = Member.new(data, server, self)
          server.add_member(member)
        end

        # Internal handler for GUILD_MEMBER_UPDATE
        def update_guild_member(data)
          server_id = data['guild_id'].to_i
          server = self.server(server_id)

          # Only attempt to update members that're already cached
          if (member = server.member(data['user']['id'].to_i, false))
            member.update_data(data)
          else
            ensure_user(data['user'])
          end
        end

        # Internal handler for GUILD_MEMBER_DELETE
        def delete_guild_member(data)
          server_id = data['guild_id'].to_i
          server = self.server(server_id)
          return unless server

          user_id = data['user']['id'].to_i
          server.delete_member(user_id)
        rescue OnyxCord::Errors::NoPermission
          OnyxCord::LOGGER.warn("delete_guild_member attempted to access a server for which the bot doesn't have permission! Not sure what happened here, ignoring")
        end

        # Internal handler for GUILD_CREATE
        def create_guild(data)
          ensure_server(data, true)
        end

        # Internal handler for GUILD_UPDATE
        def update_guild(data)
          server_id = data['id'].to_i
          server = @servers&.[](server_id)

          if server
            server.update_data(data)
          else
            LOGGER.warn("GUILD_UPDATE received for uncached server #{server_id}; caching from payload")
            ensure_server(data, true)
          end
        end

        # Internal handler for GUILD_DELETE
        def delete_guild(data)
          id = data['id'].to_i
          @servers.delete(id)
        end

        # Internal handler for GUILD_ROLE_CREATE and GUILD_ROLE_UPDATE
        def update_guild_role(data)
          server = @servers[data['guild_id'].to_i]

          if (role = server&.role(data['role']['id'].to_i))
            role.update_data(data['role'])
          else
            server&.add_role(Role.new(data['role'], self, server))
          end
        end

        # Internal handler for GUILD_ROLE_DELETE
        def delete_guild_role(data)
          role_id = data['role_id'].to_i
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          server&.delete_role(role_id)
        end

        # Internal handler for GUILD_EMOJIS_UPDATE
        def update_guild_emoji(data)
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          server&.update_emoji_data(data)
        end

        # Internal handler for GUILD_SCHEDULED_EVENT_CREATE and GUILD_SCHEDULED_EVENT_UPDATE
        def update_guild_scheduled_event(data)
          server = @servers[data['guild_id'].to_i]

          if (event = server&.scheduled_event(data['id'].to_i, request: false))
            event&.update_data(data)
          else
            server&.cache_scheduled_event(ScheduledEvent.new(data, server, self))
          end
        end

        # Internal handler for MESSAGE_CREATE
        def create_message(data); end

        # Internal handler for TYPING_START
        def start_typing(data); end

        # Internal handler for MESSAGE_UPDATE
        def update_message(data); end

        # Internal handler for MESSAGE_DELETE
        def delete_message(data); end

        # Internal handler for MESSAGE_REACTION_ADD
        def add_message_reaction(data); end

        # Internal handler for MESSAGE_REACTION_REMOVE
        def remove_message_reaction(data); end

        # Internal handler for MESSAGE_REACTION_REMOVE_ALL
        def remove_all_message_reactions(data); end

        # Internal handler for GUILD_BAN_ADD
        def add_user_ban(data); end

        # Internal handler for GUILD_BAN_REMOVE
        def remove_user_ban(data); end
      end
    end

    include Stores::Gateway
  end
end
