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

    # Check if a user has permission to do something.
    # Fast path: returns true immediately if level <= 0.
    # @param user [User] The user to check
    # @param level [Integer] The minimum permission level the user should have (inclusive)
    # @param server [Server] The server on which to check
    # @return [true, false] whether or not the user has the given permission
    def permission?(user, level, server)
      return true if level <= 0

      determined_level = if user.webhook? || server.nil?
                           0
                         else
                           user.roles.reduce(0) do |memo, role|
                             [@permissions[:roles][role.id] || 0, memo].max
                           end
                         end

      [@permissions[:users][user.id] || 0, determined_level].max >= level
    end

    private

    def required_permissions?(member, required, channel = nil)
      return true if required.nil? || required.empty?
      return false if member.webhook? || member.is_a?(OnyxCord::Recipient)

      required.all? { |action| member.permission?(action, channel) }
    end

    def required_roles?(member, required)
      return true if member.webhook? || member.is_a?(OnyxCord::Recipient) || required.nil? || required.empty?

      check_multiple_roles(member, Array(required))
    end

    def allowed_roles?(member, required)
      return true if member.webhook? || member.is_a?(OnyxCord::Recipient) || required.nil? || required.empty?

      check_multiple_roles(member, Array(required), false)
    end

    def check_multiple_roles(member, required, all_roles = true)
      if all_roles
        required.all? { |role| member.role?(role) }
      else
        required.any? { |role| member.role?(role) }
      end
    end
  end
end
