# frozen_string_literal: true

module OnyxCord
  # An ApplicationCommand for slash commands.
  class ApplicationCommand
    # Command types. `chat_input` is a command that appears in the text input field. `user` and `message` types appear as context menus
    # for the respective resource.
    TYPES = {
      chat_input: 1,
      user: 2,
      message: 3,
      primary_entry_point: 4
    }.freeze

    # @return [Integer]
    attr_reader :application_id

    # @return [Integer, nil]
    attr_reader :server_id

    # @return [String]
    attr_reader :name

    # @return [String]
    attr_reader :description

    # @return [true, false]
    attr_reader :default_permission

    # @return [Hash]
    attr_reader :options

    # @return [Integer]
    attr_reader :id

    # @return [true, false]
    attr_reader :nsfw

    # @return [Array<Integer>]
    attr_reader :contexts

    # @return [Array<Integer>]
    attr_reader :integration_types

    # @!visibility private
    def initialize(data, bot, server_id = nil)
      @bot = bot
      @id = data['id'].to_i
      @application_id = data['application_id'].to_i
      @server_id = server_id&.to_i

      @name = data['name']
      @description = data['description']
      @default_permission = data['default_permission']
      @options = data['options']
      @nsfw = data['nsfw'] || false
      @contexts = data['contexts'] || []
      @integration_types = data['integration_types'] || []
    end

    # @param subcommand [String, nil] The subcommand to mention.
    # @param subcommand_group [String, nil] The subcommand group to mention.
    # @return [String] the layout to mention it in a message
    def mention(subcommand_group: nil, subcommand: nil)
      if subcommand_group && subcommand
        "</#{name} #{subcommand_group} #{subcommand}:#{id}>"
      elsif subcommand_group
        "</#{name} #{subcommand_group}:#{id}>"
      elsif subcommand
        "</#{name} #{subcommand}:#{id}>"
      else
        "</#{name}:#{id}>"
      end
    end

    alias_method :to_s, :mention

    # @param name [String] The name to use for this command.
    # @param description [String] The description of this command.
    # @param default_permission [true, false] Whether this command is available with default permissions.
    # @param nsfw [true, false] Whether this command should be marked as age-restricted.
    # @yieldparam (see Bot#edit_application_command)
    # @return (see Bot#edit_application_command)
    def edit(name: nil, description: nil, default_permission: nil, nsfw: nil, &block)
      @bot.edit_application_command(@id, server_id: @server_id, name: name, description: description, default_permission: default_permission, nsfw: nsfw, &block)
    end

    # Delete this application command.
    # @return (see Bot#delete_application_command)
    def delete
      @bot.delete_application_command(@id, server_id: @server_id)
    end

    # Get the permission configuration for this application command in a specific server.
    # @param server_id [Integer, String, nil] The ID of the server to fetch command permissions for.
    # @return [Array<Permission>] the permissions for this application command in the given server.
    def permissions(server_id: nil)
      raise ArgumentError, 'A server ID must be provided for global application commands' if @server_id.nil? && server_id.nil?

      response = JSON.parse(REST::Application.get_application_command_permissions(@bot.token, @bot.profile.id, @server_id || server_id&.resolve_id, @id))
      response['permissions'].map { |permission| Permission.new(permission, response, @bot) }
    rescue OnyxCord::Errors::UnknownError
      # If there aren't any explicit overwrites configured for the command, the response is a 400.
      []
    end

    # An application command permission for a channel, member, or a role.
    class Permission
      # Map of permission types.
      TYPES = {
        role: 1,
        member: 2,
        channel: 3
      }.freeze

      # @return [Integer] the type of this permission.
      # @see TYPES
      attr_reader :type

      # @return [Integer] the ID of the entity this permission is for.
      attr_reader :target_id

      # @return [Integer] the ID of the server this permission is for.
      attr_reader :server_id

      # @!visibility private
      def initialize(data, command, bot)
        @bot = bot
        @type = data['type']
        @target_id = data['id'].to_i
        @overwrite = data['permission']
        @command_id = command['id'].to_i
        @server_id = command['guild_id'].to_i
        @application_id = command['application_id'].to_i
      end

      # Whether this permission has been allowed, e.g has a green check in the UI.
      # @return [true, false]
      def allowed?
        @overwrite == true
      end

      # Whether this permission has been denied, e.g has a red X-mark in the UI.
      # @return [true, false]
      def denied?
        @overwrite == false
      end

      # Whether this permission is applied to the everyone role in the server.
      # @return [true, false]
      def everyone?
        @target_id == @server_id
      end

      # Get the ID of the application command this permission is for.
      # @return [Integer, nil] This will be `nil` if the permission is the
      #   default permission.
      def command_id
        @command_id unless default?
      end

      # Whether this permission is the default for all commands that don't
      #  contain explicit permission oerwrites.
      # @return [true, false]
      def default?
        @command_id == @application_id
      end

      # Whether this permission is applied to every channel in the server.
      # @return [true, false]
      def all_channels?
        @target_id == (@server_id - 1)
      end

      # Get the user, role, or channel(s) that this permission targets.
      # @return [Array<Channel>, Role, Member]
      def target
        case @type
        when TYPES[:role]
          @bot.server(@server_id).role(@target_id)
        when TYPES[:member]
          @bot.server(@server_id).member(@target_id)
        when TYPES[:channel]
          all_channels? ? @bot.server(@server_id).channels : [@bot.channel(@target_id)]
        end
      end

      alias_method :targets, :target

      # @!method role?
      #   @return [true, false] whether this permission is for a role.
      # @!method member?
      #   @return [true, false] whether this permission is for a member.
      # @!method channel?
      #   @return [true, false] whether this permission is for a channel.
      TYPES.each do |name, value|
        define_method("#{name}?") do
          @type == value
        end
      end
    end
  end
end
