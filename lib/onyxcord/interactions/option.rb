# frozen_string_literal: true

module OnyxCord
  module Interactions
    class Option
      attr_reader :name, :description, :type, :attributes, :options

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

      SKIP_OPTION_TYPES = %i[subcommand subcommand_group].freeze

      OPTION_METHODS = OPTION_TYPES.each_with_object({}) do |(name, value), hash|
        next if SKIP_OPTION_TYPES.include?(name)

        hash[name] = value
      end.freeze

      def initialize(name, description, type, **attributes, &block)
        @name = name.to_s
        @description = description
        @type = type
        @attributes = attributes
        @options = []
        @block = block

        instance_eval(&@block) if @block && type == :subcommand
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
        data[:channel_types] = @attributes[:channel_types] if @attributes[:channel_types]

        if @attributes[:choices]
          choice_localizations = @attributes[:choice_localizations] || {}
          data[:choices] = @attributes[:choices].map do |choice_name, value|
            choice = { name: choice_name.to_s, value: value }
            locs = choice_localizations[choice_name] || choice_localizations[choice_name.to_s]
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

      OPTION_METHODS.each do |method_name, option_type|
        define_method(method_name) do |name, description = '', **attrs, &blk|
          opt = Option.new(name, description, option_type, **attrs, &blk)
          @options << opt
          opt
        end
      end
    end
  end
end
