# frozen_string_literal: true

require 'lru_redux'
require 'onyxcord/cache'
require 'onyxcord/rest/client'
require 'onyxcord/rest/routes/server'
require 'onyxcord/rest/routes/invite'
require 'onyxcord/rest/routes/user'
require 'onyxcord/core/configuration'
require 'onyxcord/models'
require 'onyxcord/cache/stores/cache_store'
require 'onyxcord/cache/stores/null_cache_store'
require 'onyxcord/cache/stores/lru_cache_store'
require 'onyxcord/cache/stores/ttl_cache_store'
require 'onyxcord/cache/stores/negative_cache_store'

module OnyxCord
  # This mixin module does caching stuff for the library. It conveniently separates the logic behind
  # the caching (like, storing the user hashes or making API calls to retrieve things) from the Bot that
  # actually uses it.
  module Cache
    CACHE_STORES = {
      users: :@users,
      voice_regions: :@voice_regions,
      servers: :@servers,
      channels: :@channels,
      pm_channels: :@pm_channels,
      thread_members: :@thread_members,
      server_previews: :@server_previews
    }.freeze

    # Maximum members cached per thread (dual-level: @thread_members LRU limits threads,
    # this limits members within each thread).
    MAX_THREAD_MEMBERS = 1000

    CACHE_LOCK_COUNT = 64
    CACHE_LOCKS = Array.new(CACHE_LOCK_COUNT) { Mutex.new }

    def with_cache_key_lock(id)
      lock = CACHE_LOCKS[id.hash.abs % CACHE_LOCK_COUNT]
      lock.synchronize do
        yield
      end
    end

    # Initializes this cache
    def init_cache
      sizes = OnyxCord.configuration.cache_sizes

      @users = Stores::LruCacheStore.new(sizes.users, enabled: cache_enabled?(:users))
      @servers = Stores::LruCacheStore.new(sizes.servers, enabled: cache_enabled?(:servers))
      @channels = Stores::LruCacheStore.new(sizes.channels, enabled: cache_enabled?(:channels))
      @pm_channels = Stores::LruCacheStore.new(sizes.pm_channels, enabled: cache_enabled?(:pm_channels))
      @thread_members = Stores::LruCacheStore.new(sizes.thread_members, enabled: cache_enabled?(:thread_members))
      @server_previews = Stores::TtlCacheStore.new(SERVER_PREVIEWS_TTL, enabled: cache_enabled?(:server_previews))
      @voice_regions = Stores::TtlCacheStore.new(VOICE_REGIONS_TTL, jitter_range: -300..300, enabled: cache_enabled?(:voice_regions))

      @request_members_rl = {}
      @request_members_rl_mutex = Mutex.new

      # Negative caches for absent entities (prevents repeated REST calls)
      @negative_users = Stores::NegativeCacheStore.new(NEGATIVE_USER_TTL, enabled: true)
      @negative_channels = Stores::NegativeCacheStore.new(NEGATIVE_CHANNEL_TTL, enabled: true)
      @negative_servers = Stores::NegativeCacheStore.new(NEGATIVE_SERVER_TTL, enabled: true)

      @channel_name_index = {}
      @user_name_index = {}
    end

    def cache_enabled?(key)
      @cache_policy.fetch(key, false)
    end

    def cache_stats
      CACHE_STORES.each_with_object({}) do |(key, ivar), stats|
        store = instance_variable_get(ivar)
        stats[key] = store.stats
      end
    end

    def prune_cache!(*keys)
      keys = CACHE_STORES.keys if keys.empty?

      keys.each_with_object({}) do |key, pruned|
        ivar = CACHE_STORES.fetch(key)
        store = instance_variable_get(ivar)
        pruned[key] = store.count
        store.clear
        store.reset_stats
      end
    end

    # Resets hit/miss/eviction counters for all cache stores (or a subset).
    def reset_cache_stats!(*keys)
      keys = CACHE_STORES.keys if keys.empty?
      keys.each { |key| instance_variable_get(CACHE_STORES.fetch(key)).reset_stats }
    end

    # Returns a health report for all caches, flagging problems like low hit rate
    # or capacity pressure. Disabled stores are skipped.
    # @return [Hash] `{ store_name => { warnings: [...], hit_rate: 0.xx, capacity_pct: 0.xx } }`
    def cache_health
      CACHE_STORES.each_with_object({}) do |(key, ivar), health|
        store = instance_variable_get(ivar)
        next unless store.enabled?

        warnings = []
        stats = store.stats
        hit_rate = stats[:hit_rate] || 0.0
        size = stats[:size] || 0
        capacity = stats[:capacity] || 0
        evictions = stats[:evictions] || 0

        if hit_rate < 0.70
          warnings << "hit_rate #{format('%.2f', hit_rate)} below 70%"
        end
        if capacity > 0 && size > 0
          pct = size.to_f / capacity
          if pct > 0.9
            warnings << "size #{size} exceeds 90% of capacity #{capacity}"
          end
        end
        if evictions > 100
          warnings << "#{evictions} evictions — consider increasing capacity"
        end

        health[key] = {
          hit_rate: hit_rate,
          capacity_pct: capacity > 0 ? (size.to_f / capacity) : 0,
          warnings: warnings
        }.freeze
      end
    end

    VOICE_REGIONS_TTL = 3600 # 1 hour
    SERVER_PREVIEWS_TTL = 86_400 # 24 hours
    NEGATIVE_USER_TTL = 30
    NEGATIVE_CHANNEL_TTL = 15
    NEGATIVE_SERVER_TTL = 10

    # Returns or caches the available voice regions
    def voice_regions
      return fetch_voice_regions unless cache_enabled?(:voice_regions)

      result = @voice_regions[:regions]
      return result if result

      @voice_regions[:regions] = fetch_voice_regions
    end

    def fetch_voice_regions
      regions_by_id = {}

      regions = JSON.parse REST.voice_regions(token)
      regions.each do |data|
        regions_by_id[data['id']] = VoiceRegion.new(data)
      end

      regions_by_id
    end

    # Gets a channel given its ID. This queries the internal channel cache, and if the channel doesn't
    # exist in there, it will get the data from Discord.
    # @param id [Integer] The channel ID for which to search for.
    # @param server [Server] The server for which to search the channel for. If this isn't specified, it will be
    #   inferred using the API
    # @return [Channel, nil] The channel identified by the ID.
    # @raise OnyxCord::Errors::NoPermission
    def channel(id, server = nil)
      id = id.resolve_id

      debug { "Obtaining data for channel with id #{id}" }
      return @channels[id] if @channels[id]
      return nil if @negative_channels[id]

      with_cache_key_lock(id) do
        return @channels[id] if @channels[id]
        return nil if @negative_channels[id]

        begin
          response = REST::Channel.resolve(token, id)
        rescue OnyxCord::Errors::UnknownChannel
          @negative_channels.add(id, ttl: NEGATIVE_CHANNEL_TTL)
          return nil
        end
        channel = Channel.new(JSON.parse(response), self, server)
        @negative_channels.remove(id)
        @channels[id] = channel
        channel
      end
    end

    alias_method :group_channel, :channel

    # Gets a user by its ID.
    # @note This can only resolve users known by the bot (i.e. that share a server with the bot).
    # @param id [Integer] The user ID that should be resolved.
    # @return [User, nil] The user identified by the ID, or `nil` if it couldn't be found.
    def user(id)
      id = id.resolve_id
      return @users[id] if @users[id]
      return nil if @negative_users[id]

      with_cache_key_lock(id) do
        return @users[id] if @users[id]
        return nil if @negative_users[id]

        @logger.out("Resolving user #{id}")
        begin
          response = REST::User.resolve(token, id)
        rescue OnyxCord::Errors::UnknownUser
          @negative_users.add(id, ttl: NEGATIVE_USER_TTL)
          return nil
        end
        user = User.new(JSON.parse(response), self)
        @negative_users.remove(id)
        @users[id] = user
        user
      end
    end

    # Gets a server by its ID.
    # @note This can only resolve servers the bot is currently in.
    # @param id [Integer] The server ID that should be resolved.
    # @return [Server, nil] The server identified by the ID, or `nil` if it couldn't be found.
    def server(id)
      id = id.resolve_id
      return @servers[id] if @servers[id]
      return nil if @negative_servers[id]

      with_cache_key_lock(id) do
        return @servers[id] if @servers[id]
        return nil if @negative_servers[id]

        @logger.out("Resolving server #{id}")
        begin
          response = REST::Server.resolve(token, id)
        rescue OnyxCord::Errors::NoPermission
          @negative_servers.add(id, ttl: NEGATIVE_SERVER_TTL)
          return nil
        end
        server = Server.new(JSON.parse(response), self)
        @negative_servers.remove(id)
        @servers[id] = server
        server
      end
    end

    # Gets a member by both IDs, or `Server` and user ID.
    # @param server_or_id [Server, Integer] The `Server` or server ID for which a member should be resolved
    # @param user_id [Integer] The ID of the user that should be resolved
    # @return [Member, nil] The member identified by the IDs, or `nil` if none could be found
    def member(server_or_id, user_id)
      server_id = server_or_id.resolve_id
      user_id = user_id.resolve_id
      server = server_or_id.is_a?(Server) ? server_or_id : self.server(server_id)

      return server.member(user_id) if server.member_cached?(user_id)

      @logger.out("Resolving member #{user_id} on server #{server_id}")
      begin
        response = REST::Server.resolve_member(token, server_id, user_id)
      rescue OnyxCord::Errors::UnknownUser, OnyxCord::Errors::UnknownMember
        return nil
      end
      member = Member.new(JSON.parse(response), server, self)
      server.cache_member(member)
      member
    end

    # Creates a PM channel for the given user ID, or if one exists already, returns that one.
    # It is recommended that you use {User#pm} instead, as this is mainly for internal use. However,
    # usage of this method may be unavoidable if only the user ID is known.
    # @param id [Integer] The user ID to generate a private channel for.
    # @return [Channel] A private channel for that user.
    def pm_channel(id)
      id = id.resolve_id
      return @pm_channels[id] if @pm_channels[id]

      with_cache_key_lock(id) do
        return @pm_channels[id] if @pm_channels[id]

        debug { "Creating pm channel with user id #{id}" }
        response = REST::User.create_pm(token, id)
        channel = Channel.new(JSON.parse(response), self)
        @pm_channels[id] = channel
        channel
      end
    end

    alias_method :private_channel, :pm_channel

    # Get a server preview. If the bot isn't a member of the server, the server must be discoverable.
    # @param id [Integer, String, Server] the ID of the server preview to get.
    # @return [ServerPreview, nil] the server preview, or `nil` if the server isn't accessible.
    def server_preview(id)
      id = id.resolve_id
      return @server_previews[id] if @server_previews[id]

      response = JSON.parse(REST::Server.preview(token, id))
      preview = ServerPreview.new(response, self)
      @server_previews[id] = preview
      preview
    rescue StandardError
      nil
    end

    # Ensures a given user object is cached and if not, cache it from the given data hash.
    # @param data [Hash] A data hash representing a user.
    # @return [User] the user represented by the data hash.
    def ensure_user(data)
      return User.new(data, self) unless cache_enabled?(:users)

      id = data['id'].to_i
      existing = @users[id]
      return existing if existing

      @negative_users.remove(id)
      user = User.new(data, self)
      @users[id] = user
      index_user_name(user)
      user
    end

    # Ensures a given server object is cached and if not, cache it from the given data hash.
    # @param data [Hash] A data hash representing a server.
    # @param force_cache [true, false] Whether the object in cache should be updated with the given
    #   data if it already exists.
    # @return [Server] the server represented by the data hash.
    def ensure_server(data, force_cache = false)
      return Server.new(data, self) unless cache_enabled?(:servers)

      id = data['id'].to_i
      existing = @servers[id]
      if existing
        existing.update_data(data) if force_cache
        return existing
      end

      @negative_servers.remove(id)
      @servers[id] = Server.new(data, self)
    end

    # Ensures a given channel object is cached and if not, cache it from the given data hash.
    # @param data [Hash] A data hash representing a channel.
    # @param server [Server, nil] The server the channel is on, if known.
    # @return [Channel] the channel represented by the data hash.
    def ensure_channel(data, server = nil)
      return Channel.new(data, self, server) unless cache_enabled?(:channels)

      id = data['id'].to_i
      existing = @channels[id]
      return existing if existing

      @negative_channels.remove(id)
      ch = Channel.new(data, self, server)
      @channels[id] = ch
      index_channel_name(ch)
      ch
    end

    # Ensures a given thread member object is cached.
    # @param data [Hash] Thread member data.
    def ensure_thread_member(data)
      return unless cache_enabled?(:thread_members)

      thread_id = data['id'].to_i
      user_id = data['user_id'].to_i

      entry = @thread_members[thread_id]
      unless entry
        # Cap members per thread to prevent unbounded inner growth
        entry = {}
        @thread_members[thread_id] = entry
      end

      # Evict oldest entry if this thread's member count exceeds the cap
      if entry.size >= MAX_THREAD_MEMBERS && !entry.key?(user_id)
        oldest_key = entry.keys.first
        entry.delete(oldest_key)
      end

      entry[user_id] = [data['join_timestamp'], data['flags']].freeze
    end

    # Requests member chunks for a given server ID.
    # @param id [Integer] The server ID to request chunks for.
    # @param server [Server, nil] The server object, used to set chunk state.
    def request_chunks(id, server = nil)
      id = id.resolve_id

      bucket = nil
      @request_members_rl_mutex.synchronize do
        bucket = (@request_members_rl[id] ||= { mutex: Mutex.new, time: Time.at(0) })
      end

      bucket[:mutex].synchronize do
        last = bucket[:time]
        now = Time.now

        if now < last
          duration = last - now

          @logger.info("Preemptively locking REQUEST_GUILD_MEMBERS for #{duration} seconds")
          sleep(duration)
        end

        nonce = "#{id}-#{Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i}-#{rand(100_000)}"
        server&.instance_variable_set(:@chunk_nonce, nonce)
        server&.instance_variable_set(:@chunk_state, :requesting) if server
        server&.instance_variable_get(:@chunk_mutex)&.synchronize do
          server.instance_variable_set(:@received_chunks, 0)
          server.instance_variable_set(:@expected_chunks, 0)
        end if server

        @gateway.send_request_members(id, '', 0, nonce)
        bucket[:time] = (Time.now + 30)
      end
    end

    # Cleans up cache entries for a guild that was deleted.
    def cleanup_guild_cache(guild_id)
      guild_id = guild_id.to_i
      @request_members_rl_mutex.synchronize do
        @request_members_rl.delete(guild_id)
      end

      return unless cache_enabled?(:channels)

      server = @servers[guild_id]
      return unless server

      server_channels = server.instance_variable_get(:@channels_by_id)
      server_channels.each_value do |ch|
        @channels.delete(ch.id)
        deindex_channel_name(ch) if @channel_name_index
      end
    end

    # Evicts the oldest cached member from a server when the per-server count exceeds a threshold.
    # @param server [Server] The server to evict from.
    def evict_from_server(server)
      server_members = server.instance_variable_get(:@members)
      return if server_members.size <= MAX_THREAD_MEMBERS

      # server_members is a Hash with insertion order — evict the oldest (first key)
      oldest_id = server_members.keys.first
      server_members.delete(oldest_id)
    end

    # Gets the code for an invite.
    # @param invite [String, Invite] The invite to get the code for. Possible formats are:
    #
    #    * An {Invite} object
    #    * The code for an invite
    #    * A fully qualified invite URL (e.g. `https://discord.com/invite/0A37aN7fasF7n83q`)
    #    * A short invite URL with protocol (e.g. `https://discord.gg/0A37aN7fasF7n83q`)
    #    * A short invite URL without protocol (e.g. `discord.gg/0A37aN7fasF7n83q`)
    # @return [String] Only the code for the invite.
    def resolve_invite_code(invite)
      invite = invite.code if invite.is_a? OnyxCord::Invite
      if invite.start_with?('http', 'discord.gg')
        i = invite.rindex('/')
        return invite unless i

        invite = invite[(i + 1)..]
      end
      invite
    end

    # Gets information about an invite.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    # @return [Invite] The invite with information about the given invite URL.
    def invite(invite)
      code = resolve_invite_code(invite)
      Invite.new(JSON.parse(REST::Invite.resolve(token, code)), self)
    end

    # Finds a channel given its name and optionally the name of the server it is in.
    # Uses secondary name index for O(1) lookup when possible.
    # @param channel_name [String] The channel to search for.
    # @param server_name [String] The server to search for, or `nil` if only the channel should be searched for.
    # @param type [Integer, nil] The type of channel to search for (0: text, 1: private, 2: voice, 3: group), or `nil` if any type of
    #   channel should be searched for
    # @return [Array<Channel>] The array of channels that were found. May be empty if none were found.
    def find_channel(channel_name, server_name = nil, type: nil)
      if /<#(?<id>\d+)>?/ =~ channel_name
        return [channel(id)]
      end

      # Fast path: use secondary name index if available
      ids = @channel_name_index[channel_name]
      if ids && !ids.empty?
        results = []
        stale_ids = []
        ids.each do |ch_id|
          ch = @channels[ch_id]
          if ch.nil?
            stale_ids << ch_id
            next
          end

          server = ch.server
          next if server_name && server && server.name != server_name
          next if type && ch.type != type

          results << ch
        end
        stale_ids.each { |sid| deindex_channel_name_by_name(channel_name, sid) }
        return results
      end

      # Slow path: full scan (index miss or not populated)
      results = []
      @servers.each_value do |server|
        server.each_channel do |ch|
          results << ch if ch.name == channel_name && (server_name || server.name) == server.name && (!type || (ch.type == type))
        end
      end

      results
    end

    # Finds a user given its username or username & discriminator.
    # Uses secondary name index for O(1) lookup when possible.
    # @overload find_user(username)
    #   Find all cached users with a certain username.
    #   @param username [String] The username to look for.
    #   @return [Array<User>] The array of users that were found. May be empty if none were found.
    # @overload find_user(username, discrim)
    #   Find a cached user with a certain username and discriminator.
    #   Find a user by name and discriminator
    #   @param username [String] The username to look for.
    #   @param discrim [String] The user's discriminator
    #   @return [User, nil] The user that was found, or `nil` if none was found
    # @note This method only searches through users that have been cached. Users that have not yet been cached
    #   by the bot but still share a connection with the user (mutual server) will not be found.
    # @example Find users by name
    #   bot.find_user('z64') #=> Array<User>
    # @example Find a user by name and discriminator
    #   bot.find_user('z64', '2639') #=> User
    def find_user(username, discrim = nil)
      # Fast path: use secondary name index if available
      ids = @user_name_index[username]
      if ids && !ids.empty?
        users = []
        stale_ids = []
        ids.each do |uid|
          user = @users[uid]
          if user.nil?
            stale_ids << uid
            next
          end
          users << user
        end
        stale_ids.each { |sid| deindex_user_name_by_name(username, sid) }
        return users.find { |u| u.discrim == discrim } if discrim
        return users
      end

      # Slow path: full scan
      users = @users.each_value.find_all { |e| e.username == username }
      return users.find { |u| u.discrim == discrim } if discrim

      users
    end

    private

    # Adds a channel to the secondary name index.
    def index_channel_name(ch)
      return unless @channel_name_index

      name = ch.name
      return unless name

      @channel_name_index[name] ||= Set.new
      @channel_name_index[name].add(ch.id)
    end

    # Removes a channel from the secondary name index.
    def deindex_channel_name(ch)
      return unless @channel_name_index

      name = ch.name
      return unless name

      @channel_name_index[name]&.delete(ch.id)
    end

    # Removes a channel from the secondary name index by name and ID.
    def deindex_channel_name_by_name(name, channel_id)
      return unless @channel_name_index && name

      ids = @channel_name_index[name]
      return unless ids

      ids.delete(channel_id)
      @channel_name_index.delete(name) if ids.empty?
    end

    # Adds a user to the secondary name index.
    def index_user_name(user)
      return unless @user_name_index

      username = user.username
      return unless username

      @user_name_index[username] ||= Set.new
      @user_name_index[username].add(user.id)
    end

    # Removes a user from the secondary name index.
    def deindex_user_name(user)
      return unless @user_name_index

      username = user.username
      return unless username

      @user_name_index[username]&.delete(user.id)
    end

    # Removes a user from the secondary name index by username and ID.
    def deindex_user_name_by_name(username, user_id)
      return unless @user_name_index && username

      ids = @user_name_index[username]
      return unless ids

      ids.delete(user_id)
      @user_name_index.delete(username) if ids.empty?
    end

    # Removes a user's old username from the index before a username change.
    def deindex_user_username(user_id, old_username)
      deindex_user_name_by_name(old_username, user_id)
    end
  end
end

require 'onyxcord/cache/stores/gateway'
