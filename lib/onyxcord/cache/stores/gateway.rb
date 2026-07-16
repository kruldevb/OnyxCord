# frozen_string_literal: true

module OnyxCord
  module Cache
    module Stores
      module Gateway
        private

        def update_presence(data)
          return unless data['guild_id']

          user_id = data['user']['id'].to_i
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          return unless server

          member_is_new = false

          if server.member_cached?(user_id)
            member = server.member(user_id)
          else
            member = Member.new(data, server, self)
            debug { "Implicitly adding presence-obtained member #{user_id} to #{server_id} cache" }

            member_is_new = true
          end

          username = data['user']['username']
          if username && !member_is_new
            debug { "Implicitly updating presence-obtained username for member #{user_id}" }
            member.update_username(username)
          end

          global_name = data['user']['global_name']
          if global_name && !member_is_new
            debug { "Implicitly updating presence-obtained global_name for member #{user_id}" }
            member.update_global_name(global_name)
          end

          member.update_presence(data)

          member.avatar_id = data['user']['avatar'] if data['user']['avatar']

          server.cache_member(member)
        end

        # Internal handler for VOICE_STATE_UPDATE
        def update_voice_state(data)
          @session_id_mutex.synchronize { @session_id = data['session_id'] } if data['user_id'].to_i == @profile&.id

          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          return unless server

          user_id = data['user_id'].to_i
          old_voice_state = server.voice_states[user_id]
          old_channel_id = old_voice_state&.channel_id || old_voice_state&.voice_channel&.id

          server.update_voice_state(data)

          existing_voice = @voices_mutex.synchronize { @voices[server_id] }
          if user_id == @profile&.id && existing_voice
            new_channel_id = data['channel_id']
            if new_channel_id
              channel_id = new_channel_id.to_i
              new_channel = @channels[channel_id] || server.channels.find { |channel| channel.id == channel_id }
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
          channel = @should_connect_voice_mutex.synchronize { @should_connect_to_voice[server_id] }

          debug { "Voice server update received! chan: #{channel.inspect}" }
          return unless channel

          @should_connect_voice_mutex.synchronize { @should_connect_to_voice.delete(server_id) }
          debug('Updating voice server!')

          token = data['token']
          endpoint = data['endpoint']

          unless endpoint
            debug('VOICE_SERVER_UPDATE sent with nil endpoint! Ignoring')
            return
          end

          debug('Got data, now creating the bot.')
          session = @session_id_mutex.synchronize { @session_id }
          voice_client = OnyxCord::Voice::Client.new(channel, self, token, session, endpoint)
          @voices_mutex.synchronize { @voices[server_id] = voice_client }
        end

        # Internal handler for CHANNEL_CREATE
        def create_channel(data)
          channel = data.is_a?(OnyxCord::Channel) ? data : Channel.new(data, self)
          server = channel.server

          channel.parent.process_last_message_id(channel.id) if channel.parent&.forum? || channel.parent&.media?

          if server
            server.add_channel(channel)
            @channels[channel.id] = channel if @channels.enabled?
          elsif channel.private?
            @pm_channels[channel.recipient.id] = channel if @pm_channels.enabled?
          elsif channel.group?
            @channels[channel.id] = channel if @channels.enabled?
          end
        end

        # Internal handler for CHANNEL_UPDATE
        def update_channel(data)
          channel = @channels[data['id'].to_i]
          return unless channel

          old_name = channel.name
          channel.update_data(data)
          new_name = channel.name
          return unless old_name != new_name

          deindex_channel_name_by_name(old_name, channel.id) if old_name
          index_channel_name(channel) if new_name
        end

        # Internal handler for CHANNEL_DELETE
        def delete_channel(data)
          channel = data.is_a?(OnyxCord::Channel) ? data : Channel.new(data, self)
          server = channel.server

          deindex_channel_name(channel)

          if server
            @channels.delete(channel.id)
            server.delete_channel(channel.id)
          elsif channel.pm?
            @pm_channels.delete(channel.recipient.id)
          elsif channel.group?
            @channels.delete(channel.id)
          end

          @thread_members.delete(channel.id) if channel.thread?
        end

        # Internal handler for GUILD_MEMBER_ADD
        def add_guild_member(data)
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          return unless server

          member = Member.new(data, server, self)
          server.add_member(member)
        end

        # Internal handler for GUILD_MEMBER_UPDATE
        def update_guild_member(data)
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          return unless server

          if (member = server.member(data['user']['id'].to_i, false))
            old_username = member.username
            member.update_data(data)
            new_username = member.username
            if old_username && new_username != old_username
              deindex_user_name_by_name(old_username, member.id)
              index_user_name(member.user)
            end
          else
            ensure_user(data['user'])
          end
        end

        # Internal handler for GUILD_MEMBER_DELETE
        def delete_guild_member(data)
          server_id = data['guild_id'].to_i
          server = @servers[server_id]
          return unless server

          user_id = data['user'].to_i
          server.delete_member(user_id)
        rescue OnyxCord::Errors::NoPermission
          @logger.warn("delete_guild_member attempted to access a server for which the bot doesn't have permission! Not sure what happened here, ignoring")
        end

        # Internal handler for GUILD_CREATE
        def create_guild(data)
          ensure_server(data, true)

          return unless cache_enabled?(:channels) || cache_enabled?(:users)

          guild_id = data['id'].to_i

          if cache_enabled?(:channels) && data['channels']
            data['channels'].each do |ch_data|
              ch_id = ch_data['id'].to_i
              @negative_channels.remove(ch_id)
            end
          end

          return unless cache_enabled?(:users) && data['members']

          data['members'].each do |member_data|
            uid = member_data['user']['id'].to_i
            @negative_users.remove(uid)
          end
        end

        # Internal handler for GUILD_UPDATE
        def update_guild(data)
          server_id = data['id'].to_i
          server = @servers[server_id]

          if server
            server.update_data(data)
          else
            @logger.warn("GUILD_UPDATE received for uncached server #{server_id}; caching from payload")
            ensure_server(data, true)
          end
        end

        # Internal handler for GUILD_DELETE
        def delete_guild(data)
          id = data['id'].to_i
          cleanup_guild_cache(id)
          @servers.delete(id)
        end

        # Internal handler for GUILD_ROLE_CREATE and GUILD_ROLE_UPDATE
        def update_guild_role(data)
          server = @servers[data['guild_id'].to_i]
          return unless server

          if (role = server.role(data['role']['id'].to_i))
            role.update_data(data['role'])
          else
            server.add_role(Role.new(data['role'], self, server))
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
