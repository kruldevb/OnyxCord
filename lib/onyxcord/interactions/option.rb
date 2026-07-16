# frozen_string_literal: true

module OnyxCord
  module Interactions
    class Option
      attr_reader :name, :description, :type, :attributes, :options, :block, :executor

      OPTION_TYPES = {
        subcommand: 1,
        subcommand_group: 2,
        string: 3,
        integer: 4,
        boolean: 5,
        user: 6,
        channel: 7,
        role: 8,
        mentionable: 9,
        number: 10,
        attachment: 11
      }.freeze

      # INT-0207: Channel types table — Discord canonical names + aliases
      CHANNEL_TYPES = {
        text: 0,
        dm: 1,
        voice: 2,
        group_dm: 3,
        category: 4,
        announcement: 5,
        news: 5,                  # alias, mantém por compat
        announcement_thread: 10,
        public_thread: 11,
        private_thread: 12,
        stage: 13,
        directory: 14,
        forum: 15,
        media: 16
      }.freeze

      SKIP_OPTION_TYPES = %i[subcommand subcommand_group].freeze

      OPTION_METHODS = OPTION_TYPES.each_with_object({}) do |(name, value), hash|
        next if SKIP_OPTION_TYPES.include?(name)

        hash[name] = value
      end.freeze

      def initialize(name, description, type, **attributes, &block)
        @name = name.to_s
        @description = description
        @type = normalize_type(type)
        @attributes = attributes
        @options = []
        @block = block
        @executor = nil

        # INT-0103: Interpretar bloco tanto de subcommand quanto de subcommand_group
        instance_eval(&@block) if @block && SKIP_OPTION_TYPES.include?(@type)

        validate!
      end

      # INT-0204/0205: Validar opção
      def validate!
        validate_name!
        validate_description!
        validate_fields_for_type!
        validate_nested_structure! if SKIP_OPTION_TYPES.include?(@type)
      end

      def validate_name!
        unless @name =~ /\A[-_\p{L}\p{N}]{1,32}\z/
          raise ArgumentError, "Invalid option name: #{@name.inspect} (must be 1-32 chars)"
        end
        if @type == :chat_input_type || (%i[subcommand subcommand_group].include?(@type) && @name != @name.downcase)
          raise ArgumentError, "Option name must be lowercase: #{@name.inspect}"
        end
      end

      def validate_description!
        len = @description.to_s.length
        unless (1..100).cover?(len)
          raise ArgumentError, "Invalid option description length: #{len} (must be 1-100 chars for '#{@name}')"
        end
      end

      # INT-0205: Validar campos conforme tipo da opção
      def validate_fields_for_type!
        case @type
        when :string
          validate_min_max_length!
        when :integer, :number
          validate_min_max_value!
        when :channel
          validate_channel_types!
        end

        validate_choices!
        validate_autocomplete!
      end

      def validate_min_max_length!
        return unless %i[string].include?(@type)
        min = @attributes[:min_length]
        max = @attributes[:max_length]
        if min && (!min.is_a?(Integer) || min < 0 || min > 6000)
          raise ArgumentError, "Invalid min_length for '#{@name}': #{min.inspect}"
        end
        if max && (!max.is_a?(Integer) || max < 1 || max > 6000)
          raise ArgumentError, "Invalid max_length for '#{@name}': #{max.inspect}"
        end
        if min && max && min > max
          raise ArgumentError, "min_length > max_length for '#{@name}'"
        end
      end

      def validate_min_max_value!
        min = @attributes[:min_value]
        max = @attributes[:max_value]
        if min && !min.is_a?(Numeric)
          raise ArgumentError, "Invalid min_value for '#{@name}': #{min.inspect}"
        end
        if max && !max.is_a?(Numeric)
          raise ArgumentError, "Invalid max_value for '#{@name}': #{max.inspect}"
        end
        if min && max && min > max
          raise ArgumentError, "min_value > max_value for '#{@name}'"
        end
      end

      def validate_channel_types!
        ct = @attributes[:channel_types] || @attributes[:types]
        return unless ct
        ct.each do |t|
          if t.is_a?(Symbol) && !CHANNEL_TYPES.key?(t)
            raise ArgumentError, "Unknown channel type: #{t.inspect}"
          end
        end
      end

      # INT-0205: choices somente em string/integer/number; autocomplete+choices proibido
      def validate_choices!
        choices = @attributes[:choices]
        return unless choices

        unless %i[string integer number].include?(@type)
          raise ArgumentError, "choices not allowed for type #{@type} on option '#{@name}'"
        end

        if choices.size > 25
          raise ArgumentError, "Too many choices for '#{@name}': #{choices.size} (max 25)"
        end
      end

      def validate_autocomplete!
        ac = @attributes[:autocomplete]
        return unless ac

        unless %i[string integer number].include?(@type)
          raise ArgumentError, "autocomplete not allowed for type #{@type} on option '#{@name}'"
        end

        if ac && @attributes[:choices]
          raise ArgumentError, "autocomplete and choices are mutually exclusive on option '#{@name}'"
        end
      end

      # INT-0204: proibir subcomandos dentro de subcomando; máximo 25 por nível
      def validate_nested_structure!
        if @type == :subcommand && @options.any? { |o| %i[subcommand subcommand_group].include?(o.type) }
          raise ArgumentError, "Cannot nest subcommands inside subcommand '#{@name}'"
        end

        if @type == :subcommand_group
          # Só pode conter subcommands, não escalares
          @options.each do |o|
            unless o.type == :subcommand
              raise ArgumentError, "subcommand_group '#{@name}' can only contain subcommands, found #{o.type}"
            end
          end
        end

        if @options.size > 25
          raise ArgumentError, "Too many options in '#{@name}': #{@options.size} (max 25)"
        end

        # Nomes únicos
        names = @options.map(&:name)
        if names.size != names.uniq.size
          raise ArgumentError, "Duplicate option names in '#{@name}': #{names.inspect}"
        end
      end

      def executor
        @executor
      end

      def execute(&block)
        @executor = block
      end

      def to_h
        data = {
          name: @name,
          description: @description,
          type: OPTION_TYPES[@type] || @type
        }

        data[:name_localizations] = @attributes[:name_localizations] if @attributes[:name_localizations]
        data[:description_localizations] = @attributes[:description_localizations] if @attributes[:description_localizations]
        data[:required] = @attributes[:required] unless @attributes[:required].nil?
        data[:min_length] = @attributes[:min_length] if @attributes[:min_length]
        data[:max_length] = @attributes[:max_length] if @attributes[:max_length]
        data[:min_value] = @attributes[:min_value] if @attributes[:min_value]
        data[:max_value] = @attributes[:max_value] if @attributes[:max_value]
        data[:autocomplete] = @attributes[:autocomplete] unless @attributes[:autocomplete].nil?

        # INT-0206: channel option normaliza types: -> channel_types
        if @type == :channel
          ct = @attributes[:channel_types] || @attributes[:types]
          if ct
            ct = ct.map { |t| t.is_a?(Symbol) ? CHANNEL_TYPES[t] || (raise ArgumentError, "Unknown channel type: #{t.inspect}") : t }
            data[:channel_types] = ct
          end
        end

        if @attributes[:choices]
          choice_localizations = @attributes[:choice_localizations] || {}
          data[:choices] = @attributes[:choices].map do |choice_name, value|
            # INT-0208: normaliza nomes para String, aceita symbolic ou string nas locs
            choice = { name: choice_name.to_s, value: value }
            locs = choice_localizations[choice_name] || choice_localizations[choice_name.to_s] || choice_localizations[choice_name.to_sym]
            choice[:name_localizations] = locs if locs
            choice
          end
        end

        data[:options] = @options.map(&:to_h) unless @options.empty?

        data
      end

      def subcommand(name, description, **attrs, &block)
        sub = Option.new(name, description, :subcommand, **attrs, &block)
        @options << sub
        sub
      end

      OPTION_METHODS.each do |method_name, _option_type|
        define_method(method_name) do |name, description = '', **attrs, &blk|
          opt = Option.new(name, description, method_name, **attrs, &blk)
          @options << opt
          opt
        end
      end

      private

      def normalize_type(value)
        if value.is_a?(Integer)
          OPTION_TYPES.invert[value] || (raise ArgumentError, "Unknown option type integer: #{value}")
        else
          value
        end
      end
    end
  end
end
