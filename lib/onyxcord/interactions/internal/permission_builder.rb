# frozen_string_literal: true

module OnyxCord
  module Interactions
    # Builder for creating server application command permissions.
    # INT-0214: Updated for Permissions v2 with channel support
    class PermissionBuilder
      # Permission types v2
      ROLE = 1
      USER = 2
      CHANNEL = 3

      MAX_ENTRIES = 100

      # @!visibility hidden
      def initialize
        @permissions = []
        @seen = {}
      end

      # Allow a role to use this command.
      # @param role_id [Integer]
      # @return [PermissionBuilder]
      def allow_role(role_id)
        create_entry(role_id, ROLE, true)
      end

      # Deny a role usage of this command.
      # @param role_id [Integer]
      # @return [PermissionBuilder]
      def deny_role(role_id)
        create_entry(role_id, ROLE, false)
      end

      # Allow a user to use this command.
      # @param user_id [Integer]
      # @return [PermissionBuilder]
      def allow_user(user_id)
        create_entry(user_id, USER, true)
      end

      # Deny a user usage of this command.
      # @param user_id [Integer]
      # @return [PermissionBuilder]
      def deny_user(user_id)
        create_entry(user_id, USER, false)
      end

      # INT-0214: Allow a channel
      # @param channel_id [Integer]
      # @return [PermissionBuilder]
      def allow_channel(channel_id)
        create_entry(channel_id, CHANNEL, true)
      end

      # INT-0214: Deny a channel
      # @param channel_id [Integer]
      # @return [PermissionBuilder]
      def deny_channel(channel_id)
        create_entry(channel_id, CHANNEL, false)
      end

      # INT-0214: Allow @everyone
      # @param server_id [Integer] The server ID (used as @everyone role ID)
      # @return [PermissionBuilder]
      def allow_everyone(server_id)
        create_entry(server_id, ROLE, true)
      end

      # INT-0214: Deny @everyone
      # @param server_id [Integer] The server ID
      # @return [PermissionBuilder]
      def deny_everyone(server_id)
        create_entry(server_id, ROLE, false)
      end

      # INT-0214: Allow all channels
      # @param server_id [Integer] The server ID (all channels is server_id - 1)
      # @return [PermissionBuilder]
      def allow_all_channels(server_id)
        create_entry(server_id - 1, CHANNEL, true)
      end

      # INT-0214: Deny all channels
      # @param server_id [Integer]
      # @return [PermissionBuilder]
      def deny_all_channels(server_id)
        create_entry(server_id - 1, CHANNEL, false)
      end

      # Allow an entity to use this command.
      # @param object [Role, User, Member, Channel]
      # @return [PermissionBuilder]
      # @raise [ArgumentError]
      def allow(object)
        case object
        when OnyxCord::User, OnyxCord::Member
          create_entry(object.id, USER, true)
        when OnyxCord::Role
          create_entry(object.id, ROLE, true)
        when OnyxCord::Channel
          create_entry(object.id, CHANNEL, true)
        else
          raise ArgumentError, "Unable to create permission for unknown type: #{object.class}"
        end
      end

      # Deny an entity usage of this command.
      # @param object [Role, User, Member, Channel]
      # @return [PermissionBuilder]
      # @raise [ArgumentError]
      def deny(object)
        case object
        when OnyxCord::User, OnyxCord::Member
          create_entry(object.id, USER, false)
        when OnyxCord::Role
          create_entry(object.id, ROLE, false)
        when OnyxCord::Channel
          create_entry(object.id, CHANNEL, false)
        else
          raise ArgumentError, "Unable to create permission for unknown type: #{object.class}"
        end
      end

      # @!visibility private
      # @return [Array<Hash>]
      def to_a
        @permissions
      end

      # INT-0214: tamanho atual
      def size
        @permissions.size
      end

      # INT-0214: atingiu o máximo?
      def full?
        @permissions.size >= MAX_ENTRIES
      end

      private

      # INT-0214: deduplicação, snowflakes normalizados, máximo 100
      def create_entry(id, type, permission)
        id = id.to_i
        key = [type, id]

        if @seen.key?(key)
          # Atualizar permissão existente
          @permissions.map! do |e|
            e[:id] == id && e[:type] == type ? e.merge(permission: permission) : e
          end
        else
          if @permissions.size >= MAX_ENTRIES
            raise ArgumentError, "Too many permission entries (max #{MAX_ENTRIES})"
          end

          @permissions << { id: id, type: type, permission: permission }
          @seen[key] = true
        end

        self
      end
    end
  end
end
