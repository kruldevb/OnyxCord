# frozen_string_literal: true

module OnyxCord
  module Interactions
    class Command
      attr_reader :name, :description, :type, :attributes, :options, :block, :handler

      TYPES = {
        chat_input: 1,
        user: 2,
        message: 3,
        primary_entry_point: 4
      }.freeze

      DESCRIPTION_TYPES = %i[chat_input primary_entry_point].freeze

      # INT-0202: Interactive contexts
      CONTEXTS = {
        guild: 0,
        bot_dm: 1,
        private_channel: 2
      }.freeze

      # INT-0202: Integration types
      INTEGRATION_TYPES = {
        guild_install: 0,
        user_install: 1
      }.freeze

      def self.chat_input(name, description:, **attributes, &block)
        new(name, description: description, type: :chat_input, **attributes, &block)
      end

      def self.user(name, **attributes, &block)
        new(name, description: '', type: :user, **attributes, &block)
      end

      def self.message(name, **attributes, &block)
        new(name, description: '', type: :message, **attributes, &block)
      end

      def self.primary_entry_point(name, description:, **attributes, &block)
        new(name, description: description, type: :primary_entry_point, **attributes, &block)
      end

      def initialize(name, description: '', type: :chat_input, **attributes, &block)
        @name = name.to_s
        @description = description
        @type = normalize_type(type)
        @attributes = attributes
        @options = []
        @block = block
        @executor = nil
        @default_member_permissions = normalize_permissions(attributes[:default_member_permissions])
        @nsfw = attributes[:nsfw]
        @contexts = normalize_contexts(attributes[:contexts])
        @dm_permission = attributes.fetch(:dm_permission, true)
        @name_localizations = attributes[:name_localizations]
        @description_localizations = attributes[:description_localizations]
        @integration_types = normalize_integration_types(attributes[:integration_types])
        @handler = attributes[:handler]

        instance_eval(&@block) if @block

        validate_primary_entry_point!
        validate_command!
      end

      def parse(&block)
        instance_eval(&block) if block
        self
      end

      def execute(&block)
        @executor = block
      end

      def call(context)
        return unless @executor

        @executor.call(context)
      end

      def subcommands
        @options.select { |o| o.type == :subcommand }
      end

      def subcommand_groups
        @options.select { |o| o.type == :subcommand_group }
      end

      def find_subcommand(name)
        @options.find { |o| (o.type == :subcommand || o.type == :subcommand_group) && o.name == name.to_s }
      end

      def root_executor
        @executor
      end

      # INT-0201: serialização sensível ao escopo
      # server_id nil = global; server_id presente = guild command
      def to_h(server_id: nil)
        guild_command = !server_id.nil?

        data = {
          name: @name,
          type: TYPES[@type] || @type
        }

        if DESCRIPTION_TYPES.include?(@type)
          data[:description] = @description
          data[:description_localizations] = @description_localizations if @description_localizations
        end

        data[:name_localizations] = @name_localizations if @name_localizations

        # INT-0109: PRIMARY_ENTRY_POINT proíbe opções; handler OBRIGATÓRIO
        if @type != :primary_entry_point
          data[:options] = @options.map(&:to_h) unless @options.empty?
        end

        # INT-0102: perm já é Integer; serializa como string decimal
        data[:default_member_permissions] = @default_member_permissions.to_s if @default_member_permissions

        # INT-0201: dm_permission/contexts/integration_types só em global
        # Discord recomenda contexts em vez de dm_permission para global
        if !guild_command
          data[:dm_permission] = @dm_permission if @type == :chat_input
          data[:contexts] = @contexts if @contexts
          data[:integration_types] = @integration_types if @integration_types
        end

        data[:nsfw] = @nsfw if @nsfw

        # INT-0109: PRIMARY_ENTRY_POINT serializa handler
        data[:handler] = @handler if @type == :primary_entry_point && @handler

        # INT-0201: PRIMARY_ENTRY_POINT nunca em guild
        if @type == :primary_entry_point && guild_command
          raise ArgumentError, "PRIMARY_ENTRY_POINT cannot be a guild command"
        end

        data
      end

      OnyxCord::Interactions::Option::OPTION_METHODS.each do |method_name, _option_type|
        define_method(method_name) do |name, description = '', **attrs, &blk|
          opt = OnyxCord::Interactions::Option.new(name, description, method_name, **attrs, &blk)
          @options << opt
          opt
        end
      end

      def subcommand(name, description, &block)
        sub = OnyxCord::Interactions::Option.new(name, description, :subcommand, &block)
        @options << sub
        sub
      end

      def subcommand_group(name, description, &block)
        group = OnyxCord::Interactions::Option.new(name, description, :subcommand_group, &block)
        @options << group
        group
      end

      private

      # INT-0102: Normalizar default_member_permissions via Permissions.bits
      def normalize_permissions(value)
        case value
        when nil then nil
        when Integer then value
        when String then value.to_i.to_s == value ? value.to_i : resolve_permission_string(value)
        when Array then OnyxCord::Permissions.bits(value.map(&:to_sym))
        when Symbol then OnyxCord::Permissions.bits([value])
        else
          raise ArgumentError, "Invalid default_member_permissions: #{value.inspect}"
        end
      end

      def resolve_permission_string(value)
        # last resort: parse cleanly as decimal string
        Integer(value, 10)
      rescue ArgumentError
        raise ArgumentError, "Invalid permission string: #{value.inspect}"
      end

      # INT-0202: Normalizar tipo de comando symbol→integer→symbol
      def normalize_type(value)
        if value.is_a?(Symbol)
          unless TYPES.key?(value)
            raise ArgumentError, "Unknown command type: #{value.inspect}. Valid: #{TYPES.keys.inspect}"
          end
          value
        elsif value.is_a?(Integer)
          TYPES.invert[value] || (raise ArgumentError, "Unknown command type integer: #{value}")
        else
          raise ArgumentError, "Invalid command type: #{value.inspect}"
        end
      end

      def normalize_contexts(value)
        return nil unless value
        value.map do |c|
          c.is_a?(Symbol) ? CONTEXTS[c] || (raise ArgumentError, "Unknown context: #{c.inspect}") : c
        end
      end

      def normalize_integration_types(value)
        return nil unless value
        value.map do |it|
          it.is_a?(Symbol) ? INTEGRATION_TYPES[it] || (raise ArgumentError, "Unknown integration type: #{it.inspect}") : it
        end
      end

      # INT-0109: Validar PRIMARY_ENTRY_POINT
      def validate_primary_entry_point!
        return unless @type == :primary_entry_point

        unless @options.empty?
          raise ArgumentError, 'PRIMARY_ENTRY_POINT cannot have options'
        end

        unless @handler
          raise ArgumentError, 'PRIMARY_ENTRY_POINT requires a handler: :APP_HANDLER or :DISCORD_LAUNCH_ACTIVITY'
        end

        valid_handlers = %i[APP_HANDLER DISCORD_LAUNCH_ACTIVITY].freeze
        unless valid_handlers.include?(@handler)
          raise ArgumentError, "Invalid PRIMARY_ENTRY_POINT handler: #{@handler.inspect}. Valid: #{valid_handlers.inspect}"
        end
      end

      # INT-0203: Validar comando antes da rede
      def validate_command!
        validate_name!
        validate_description!
        validate_options_structure!
        validate_options_count!
      end

      def validate_name!
        case @type
        when :chat_input
          # lowercase, 1-32 chars, ^[-_\p{L}\p{N}]{1,32}$
          unless @name =~ /\A[-_\p{L}\p{N}]{1,32}\z/
            raise ArgumentError, "Invalid chat_input name: #{@name.inspect} (must be 1-32 chars, lowercase letters/numbers/-/_)"
          end
          unless @name == @name.downcase
            raise ArgumentError, "chat_input name must be lowercase: #{@name.inspect}"
          end
        when :user, :message
          # 1-32 chars, any
          unless (1..32).cover?(@name.length)
            raise ArgumentError, "Invalid #{@type} name length: #{@name.inspect} (must be 1-32 chars)"
          end
        when :primary_entry_point
          unless (1..32).cover?(@name.length)
            raise ArgumentError, "Invalid primary_entry_point name length: #{@name.inspect}"
          end
        end
      end

      def validate_description!
        return unless DESCRIPTION_TYPES.include?(@type)

        len = @description.to_s.length
        unless (1..100).cover?(len)
          raise ArgumentError, "Invalid description length for #{@type}: #{len} (must be 1-100 chars)"
        end
      end

      # INT-0204: Validar estrutura das opções
      def validate_options_structure!
        return if @options.empty?

        types = @options.map(&:type).to_set

        # Proibir mistura de subcomandos com parâmetros escalares no mesmo nível
        has_sub = types.intersect?(%i[subcommand subcommand_group].to_set)
        has_scalar = types.intersect?(%i[string integer boolean user channel role mentionable number attachment].to_set)
        if has_sub && has_scalar
          raise ArgumentError, "Cannot mix subcommands/subcommand_groups with scalar options in the same level"
        end

        # Required antes de opcionais
        required_first = true
        @options.each do |opt|
          is_required = opt.attributes[:required] == true
          if is_required == false && required_first
            required_first = false
          elsif is_required == true && !required_first
            raise ArgumentError, "Required option '#{opt.name}' must come before optional options"
          end
        end

        # Nomes únicos
        names = @options.map(&:name)
        if names.size != names.uniq.size
          raise ArgumentError, "Duplicate option names: #{names.inspect}"
        end
      end

      # INT-0203: máximo 25 opções por nível
      def validate_options_count!
        return if @options.empty?
        if @options.size > 25
          raise ArgumentError, "Too many options: #{@options.size} (max 25 per level)"
        end
      end
    end
  end
end
