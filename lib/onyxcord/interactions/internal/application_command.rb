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

    # @return [String, nil]
    attr_reader :description

    # @return [true, false, nil]
    attr_reader :default_permission

    # @return [Array<Hash>, nil] — nil quando ausente, [] quando vazio
    attr_reader :options

    # @return [Integer]
    attr_reader :id

    # @return [true, false]
    attr_reader :nsfw

    # @return [Array<Integer>, nil] — nil quando ausente, não []
    attr_reader :contexts

    # @return [Array<Integer>, nil]
    attr_reader :integration_types

    # INT-0210: campos adicionais lidos do payload
    # @return [String, nil]
    attr_reader :default_member_permissions

    # @return [Integer, nil]
    attr_reader :version

    # @return [Hash, nil]
    attr_reader :name_localizations

    # @return [Hash, nil]
    attr_reader :description_localizations

    # @return [true, false, nil]
    attr_reader :dm_permission

    # @return [Symbol, nil]
    attr_reader :handler

    # @return [Integer, nil]
    attr_reader :type

    # @!visibility private
    def initialize(data, bot, server_id = nil)
      @bot = bot
      @id = data['id'].to_i
      @application_id = data['application_id'].to_i
      @server_id = server_id&.to_i || data['guild_id']&.to_i

      @name = data['name']
      @description = data['description']
      @default_permission = data['default_permission']
      # INT-0210: não converter [] para nil — ausência e vazio têm significados diferentes
      @options = data.key?('options') ? data['options'] : nil
      @nsfw = data['nsfw'] || false
      @contexts = data.key?('contexts') ? data['contexts'] : nil
      @integration_types = data.key?('integration_types') ? data['integration_types'] : nil
      @default_member_permissions = data['default_member_permissions']
      @version = data['version']&.to_i
      @name_localizations = data['name_localizations']
      @description_localizations = data['description_localizations']
      @dm_permission = data['dm_permission']
      @handler = data['handler']&.to_sym
      @type = data['type']
    end

    # @return [Symbol] Symbol do tipo do comando
    def command_type
      TYPES.invert[@type] || :unknown
    end

    # INT-0212: Validar menção antes de produzir a string
    # @param subcommand [String, nil] The subcommand to mention.
    # @param subcommand_group [String, nil] The subcommand group to mention.
    # @return [String] the layout to mention it in a message
    def mention(subcommand_group: nil, subcommand: nil)
      if subcommand_group && !subcommand
        raise ArgumentError, "subcommand_group requires subcommand for mention"
      end

      # Validar que grupo e subcomando existem na árvore
      if subcommand_group || subcommand
        validate_mention_path!(subcommand_group, subcommand)
      end

      if subcommand_group && subcommand
        "</#{name} #{subcommand_group} #{subcommand}:#{id}>"
      elsif subcommand
        "</#{name} #{subcommand}:#{id}>"
      else
        "</#{name}:#{id}>"
      end
    end

    alias_method :to_s, :mention

    # INT-0211: edit seguro — não enviar type:1 por padrão; campos não editáveis omitidos
    # @param name [String] The name to use for this command.
    # @param description [String] The description of this command.
    # @param default_permission [true, false] Whether this command is available with default permissions.
    # @param nsfw [true, false] Whether this command should be marked as age-restricted.
    # @param options [Array<Hash>] Options to update.
    # @param default_member_permissions [Integer, Array<Symbol>, nil] Permission bits.
    # @param contexts [Array<Integer>, nil] Contexts.
    # @param integration_types [Array<Integer>, nil] Integration types.
    # @param dm_permission [true, false, nil] DM permission.
    # @param name_localizations [Hash, nil] Name localizations.
    # @param description_localizations [Hash, nil] Description localizations.
    # @param handler [Symbol, nil] PRIMARY_ENTRY_POINT handler.
    # @yieldparam (see Bot#edit_application_command)
    # @return (see Bot#edit_application_command)
    def edit(
      name: nil, description: nil, default_permission: nil, nsfw: nil,
      options: nil, default_member_permissions: nil, contexts: nil,
      integration_types: nil, dm_permission: nil,
      name_localizations: nil, description_localizations: nil, handler: nil, &block
    )
      # type não é enviado a menos que seja relevante
      @bot.edit_application_command(
        @id, server_id: @server_id,
        name: name, description: description,
        default_permission: default_permission, nsfw: nsfw,
        options: options, default_member_permissions: default_member_permissions,
        contexts: contexts, integration_types: integration_types,
        dm_permission: dm_permission,
        name_localizations: name_localizations,
        description_localizations: description_localizations,
        handler: handler,
        &block
      )
    end

    # Delete this application command.
    # @return (see Bot#delete_application_command)
    def delete
      @bot.delete_application_command(@id, server_id: @server_id)
    end

    # INT-0213: Não esconder erros de permissões
    # Get the permission configuration for this application command in a specific server.
    # @param server_id [Integer, String, nil] The ID of the server to fetch command permissions for.
    # @return [Array<Permission>] the permissions for this application command in the given server.
    def permissions(server_id: nil)
      raise ArgumentError, 'A server ID must be provided for global application commands' if @server_id.nil? && server_id.nil?

      response = JSON.parse(REST::Application.get_application_command_permissions(@bot.token, @bot.profile.id, @server_id || server_id&.resolve_id, @id))

      # INT-0213: retornar [] somente quando a API responde validamente com lista vazia
      return [] if response['permissions'].empty?

      response['permissions'].map { |permission| Permission.new(permission, response, @bot) }
    end

    private

    # INT-0212: Validar que a rota existe na árvore de opções
    def validate_mention_path!(group, sub)
      opts = @options || []
      return if opts.empty?

      if group
        group_opt = opts.find { |o| o['name'] == group.to_s }
        unless group_opt && group_opt['type'] == 2
          raise ArgumentError, "subcommand_group '#{group}' not found in command '#{@name}'"
        end

        if sub
          sub_opt = group_opt['options']&.find { |o| o['name'] == sub.to_s }
          unless sub_opt && sub_opt['type'] == 1
            raise ArgumentError, "subcommand '#{sub}' not found in group '#{group}'"
          end
        end
      elsif sub
        sub_opt = opts.find { |o| o['name'] == sub.to_s && o['type'] == 1 }
        unless sub_opt
          raise ArgumentError, "subcommand '#{sub}' not found in command '#{@name}'"
        end
      end
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
        # INT-0215: memorização de target nil
        @target_cache = nil
        @target_cached = false
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
      # INT-0215: checa o tipo também
      # @return [true, false]
      def all_channels?
        @type == TYPES[:channel] && @target_id == (@server_id - 1)
      end

      # INT-0215: target consistente — memoriza inclusive nil, evitar buscas repetidas
      # Get the user, role, or channel(s) that this permission targets.
      # @return [Array<Channel>, Role, Member, nil]
      def target
        return @target_cache if @target_cached
        @target_cached = true
        @target_cache = resolve_target
      end

      # INT-0215: targets retorna array consistentemente (exceto all_channels?)
      def targets
        t = target
        return t if t.is_a?(Array)
        t ? [t] : []
      end

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

      private

      # INT-0215, INT-0302: resolução REST explícita — não implícita
      def resolve_target
        sv = @bot.server(@server_id)
        return nil unless sv

        case @type
        when TYPES[:role]
          sv.role(@target_id)
        when TYPES[:member]
          sv.member(@target_id)
        when TYPES[:channel]
          all_channels? ? sv.channels : [@bot.channel(@target_id)]
        end
      end
    end
  end
end
