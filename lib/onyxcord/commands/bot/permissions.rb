# frozen_string_literal: true

class OnyxCord::Commands::Bot
  module Permissions
    # Sets the permission level of a user
    # @param id [Integer] the ID of the user whose level to set
    # @param level [Integer] the level to set the permission to
    def set_user_permission(id, level)
      @permissions[:users][id] = level
    end

    # Sets the permission level of a role - this applies to all users in the role
    # @param id [Integer] the ID of the role whose level to set
    # @param level [Integer] the level to set the permission to

    def set_role_permission(id, level)
      @permissions[:roles][id] = level
    end

    # Check if a user has permission to do something
    # @param user [User] The user to check
    # @param level [Integer] The minimum permission level the user should have (inclusive)
    # @param server [Server] The server on which to check
    # @return [true, false] whether or not the user has the given permission

    def permission?(user, level, server)
      determined_level = if user.webhook? || server.nil?
                           0
                         else
                           user.roles.reduce(0) do |memo, role|
                             [@permissions[:roles][role.id] || 0, memo].max
                           end
                         end

      [@permissions[:users][user.id] || 0, determined_level].max >= level
    end

    # @see Commands::Bot#update_channels

    private

    def required_permissions?(member, required, channel = nil)
      required.reduce(true) do |a, action|
        a && !member.webhook? && !member.is_a?(OnyxCord::Recipient) && member.permission?(action, channel)
      end
    end

    def required_roles?(member, required)
      return true if member.webhook? || member.is_a?(OnyxCord::Recipient) || required.nil? || required.empty?

      required.is_a?(Array) ? check_multiple_roles(member, required) : member.role?(role)
    end

    def allowed_roles?(member, required)
      return true if member.webhook? || member.is_a?(OnyxCord::Recipient) || required.nil? || required.empty?

      required.is_a?(Array) ? check_multiple_roles(member, required, false) : member.role?(role)
    end

    def check_multiple_roles(member, required, all_roles = true)
      if all_roles
        required.all? do |role|
          member.role?(role)
        end
      else
        required.any? do |role|
          member.role?(role)
        end
      end
    end
  end
end
