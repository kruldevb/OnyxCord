# frozen_string_literal: true

module OnyxCord
  module Interactions
    # Builder for creating server application command permissions.
    # @deprecated This system is being replaced in the near future.
    class PermissionBuilder
      # Role permission type
      ROLE = 1
      # User permission type
      USER = 2

      # @!visibility hidden
      def initialize
        @permissions = []
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

      # Allow an entity to use this command.
      # @param object [Role, User, Member]
      # @return [PermissionBuilder]
      # @raise [ArgumentError]
      def allow(object)
        case object
        when OnyxCord::User, OnyxCord::Member
          create_entry(object.id, USER, true)
        when OnyxCord::Role
          create_entry(object.id, ROLE, true)
        else
          raise ArgumentError, "Unable to create permission for unknown type: #{object.class}"
        end
      end

      # Deny an entity usage of this command.
      # @param object [Role, User, Member]
      # @return [PermissionBuilder]
      # @raise [ArgumentError]
      def deny(object)
        case object
        when OnyxCord::User, OnyxCord::Member
          create_entry(object.id, USER, false)
        when OnyxCord::Role
          create_entry(object.id, ROLE, false)
        else
          raise ArgumentError, "Unable to create permission for unknown type: #{object.class}"
        end
      end

      # @!visibility private
      # @return [Array<Hash>]
      def to_a
        @permissions
      end

      private

      def create_entry(id, type, permission)
        @permissions << { id: id, type: type, permission: permission }
        self
      end
    end
  end
end
