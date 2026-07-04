# frozen_string_literal: true

module OnyxCord
  class Bot
    module ApplicationCommands
      # Get all application commands.
      # @param server_id [String, Integer, nil] The ID of the server to get the commands from. Global if `nil`.
      # @return [Array<ApplicationCommand>]
      def get_application_commands(server_id: nil)
        resp = if server_id
                 REST::Application.get_guild_commands(@token, profile.id, server_id)
               else
                 REST::Application.get_global_commands(@token, profile.id)
               end

        JSON.parse(resp).map do |command_data|
          ApplicationCommand.new(command_data, self, server_id)
        end
      end

      # Get an application command by ID.
      # @param command_id [String, Integer]
      # @param server_id [String, Integer, nil] The ID of the server to get the command from. Global if `nil`.
      def get_application_command(command_id, server_id: nil)
        resp = if server_id
                 REST::Application.get_guild_command(@token, profile.id, server_id, command_id)
               else
                 REST::Application.get_global_command(@token, profile.id, command_id)
               end
        ApplicationCommand.new(JSON.parse(resp), self, server_id)
      end

      # @return [OnyxCord::Interactions::Registry]
      def commands
        @commands ||= ApplicationCommands::Registry.new(self)
      end

      def slash(name, description: nil, **attributes, &block)
        commands.slash(name, description: description, **attributes, &block)
      end

      def user_command(name, **attributes, &block)
        commands.user(name, **attributes, &block)
      end

      def message_command(name, **attributes, &block)
        commands.message(name, **attributes, &block)
      end

      def sync_application_commands!(server_id: nil, delete_unknown: false)
        commands.sync!(server_id: server_id, delete_unknown: delete_unknown)
      end

      def bulk_overwrite_global_application_commands(commands)
        response = REST::Application.bulk_overwrite_global_commands(@token, profile.id, commands)
        JSON.parse(response).map { |data| ApplicationCommand.new(data, self) }
      end

      def bulk_overwrite_guild_application_commands(server_id, commands)
        response = REST::Application.bulk_overwrite_guild_commands(@token, profile.id, server_id.resolve_id, commands)
        JSON.parse(response).map { |data| ApplicationCommand.new(data, self, server_id) }
      end

      # @yieldparam [OptionBuilder]
      # @yieldparam [PermissionBuilder]
      # @example
      #   bot.register_application_command(:reddit, 'Reddit Commands') do |cmd|
      #     cmd.subcommand_group(:subreddit, 'Subreddit Commands') do |group|
      #       group.subcommand(:hot, "What's trending") do |sub|
      #         sub.string(:subreddit, 'Subreddit to search')
      #       end
      #       group.subcommand(:new, "What's new") do |sub|
      #         sub.string(:since, 'How long ago', choices: ['this hour', 'today', 'this week', 'this month', 'this year', 'all time'])
      #         sub.string(:subreddit, 'Subreddit to search')
      #       end
      #     end
      #   end
      def register_application_command(name, description, server_id: nil, default_permission: nil, type: :chat_input, default_member_permissions: nil, contexts: nil, nsfw: false, integration_types: nil)
        type = ApplicationCommand::TYPES[type] || type

        contexts = contexts&.map { |context| Interaction::CONTEXTS[context] || context }
        integration_types = integration_types&.map { |type| Interaction::INTEGRATION_TYPES[type] || type }
        default_member_permissions = Permissions.bits(default_member_permissions) if default_member_permissions.is_a?(Array)

        builder = Interactions::OptionBuilder.new
        permission_builder = Interactions::PermissionBuilder.new
        yield(builder, permission_builder) if block_given?

        resp = if server_id
                 REST::Application.create_guild_command(@token, profile.id, server_id, name, description, builder.to_a, default_permission, type, default_member_permissions&.to_s, contexts, nsfw)
               else
                 REST::Application.create_global_command(@token, profile.id, name, description, builder.to_a, default_permission, type, default_member_permissions&.to_s, contexts, nsfw, integration_types)
               end
        cmd = ApplicationCommand.new(JSON.parse(resp), self, server_id)

        if permission_builder.to_a.any?
          raise ArgumentError, 'Permissions can only be set for guild commands' unless server_id

          edit_application_command_permissions(cmd.id, server_id, permission_builder.to_a)
        end

        cmd
      end

      # @yieldparam [OptionBuilder]
      # @yieldparam [PermissionBuilder]
      def edit_application_command(command_id, server_id: nil, name: nil, description: nil, default_permission: nil, type: :chat_input, default_member_permissions: nil, contexts: nil, nsfw: nil, integration_types: nil)
        type = ApplicationCommand::TYPES[type] || type

        contexts = contexts&.map { |context| Interaction::CONTEXTS[context] || context }
        integration_types = integration_types&.map { |type| Interaction::INTEGRATION_TYPES[type] || type }
        default_member_permissions = Permissions.bits(default_member_permissions) if default_member_permissions.is_a?(Array)

        builder = Interactions::OptionBuilder.new
        permission_builder = Interactions::PermissionBuilder.new

        yield(builder, permission_builder) if block_given?

        resp = if server_id
                 REST::Application.edit_guild_command(@token, profile.id, server_id, command_id, name, description, builder.to_a, default_permission, type, default_member_permissions&.to_s, contexts, nsfw)
               else
                 REST::Application.edit_global_command(@token, profile.id, command_id, name, description, builder.to_a, default_permission, type, default_member_permissions&.to_s, contexts, nsfw, integration_types)
               end
        cmd = ApplicationCommand.new(JSON.parse(resp), self, server_id)

        if permission_builder.to_a.any?
          raise ArgumentError, 'Permissions can only be set for guild commands' unless server_id

          edit_application_command_permissions(cmd.id, server_id, permission_builder.to_a)
        end

        cmd
      end

      # Remove an application command from the commands registered with discord.
      # @param command_id [String, Integer] The ID of the command to remove.
      # @param server_id [String, Integer] The ID of the server to delete this command from, global if `nil`.
      def delete_application_command(command_id, server_id: nil)
        if server_id
          REST::Application.delete_guild_command(@token, profile.id, server_id, command_id)
        else
          REST::Application.delete_global_command(@token, profile.id, command_id)
        end
      end

      # @param command_id [Integer, String]
      # @param server_id [Integer, String]
      # @param permissions [Array<Hash>] An array of objects formatted as `{ id: ENTITY_ID, type: 1 or 2, permission: true or false }`
      # @param bearer_token [String] A valid bearer token that has permission to manage the server and its roles.
      def edit_application_command_permissions(command_id, server_id, permissions = [], bearer_token = nil)
        builder = Interactions::PermissionBuilder.new
        yield builder if block_given?

        raise ArgumentError, 'This method requires a valid bearer token to be provided' unless bearer_token

        permissions += builder.to_a
        bearer_token = "Bearer #{bearer_token.delete_prefix('Bearer ')}"
        REST::Application.edit_guild_command_permissions(bearer_token, profile.id, server_id, command_id, permissions)
      end

      # Get the permissions for all of the application commands in a specific server.
      # @param server_id [Integer, String, nil] The ID of the server to fetch application command permissions for.
      # @return [Array<ApplicationCommand::Permission>] The permissions for all of the application commands in the given server.
      def application_command_permissions(server_id:)
        response = REST::Application.get_guild_application_command_permissions(@token, profile.id, server_id.resolve_id)
        JSON.parse(response).flat_map { |data| data['permissions'].map { |inner| ApplicationCommand::Permission.new(inner, data, self) } }
      end

      # Fetches all the application emojis that the bot can use.
      # @return [Array<Emoji>] Returns an array of emoji objects.
      def application_emojis
        response = REST::Application.list_application_emojis(@token, profile.id)
        JSON.parse(response)['items'].map { |emoji| Emoji.new(emoji, self) }
      end

      # Fetches a single application emoji from its ID.
      # @param emoji_id [Integer, String] ID of the application emoji.
      # @return [Emoji] The application emoji.
      def application_emoji(emoji_id)
        response = REST::Application.get_application_emoji(@token, profile.id, emoji_id.resolve_id)
        Emoji.new(JSON.parse(response), self)
      end

      # Creates a new custom emoji that can be used by this application.
      # @param name [String] The name of emoji to create.
      # @param image [String, #read] Base64 string with the image data, or an object that responds to #read.
      # @return [Emoji] The emoji that has been created.
      def create_application_emoji(name:, image:)
        image = image.respond_to?(:read) ? OnyxCord.encode64(image) : image
        response = REST::Application.create_application_emoji(@token, profile.id, name, image)
        Emoji.new(JSON.parse(response), self)
      end

      # Edits an existing application emoji.
      # @param emoji_id [Integer, String, Emoji] ID of the application emoji to edit.
      # @param name [String] The new name of the emoji.
      # @return [Emoji] Returns the updated emoji object on success.
      def edit_application_emoji(emoji_id, name:)
        response = REST::Application.edit_application_emoji(@token, profile.id, emoji_id.resolve_id, name)
        Emoji.new(JSON.parse(response), self)
      end

      # Deletes an existing application emoji.
      # @param emoji_id [Integer, String, Emoji] ID of the application emoji to delete.
      def delete_application_emoji(emoji_id)
        REST::Application.delete_application_emoji(@token, profile.id, emoji_id.resolve_id)
      end
    end
  end
end
