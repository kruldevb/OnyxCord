# frozen_string_literal: true

module OnyxCord
  module Interactions
    # A builder for defining slash commands options.
    # INT-0216: OptionBuilder é uma fachada pública que delega para Option,
    # garantindo validação e serialização unificadas.
    class OptionBuilder
      # @!visibility private
      TYPES = Option::OPTION_TYPES

      # INT-0207: Channel types sincronizado com Option
      CHANNEL_TYPES = Option::CHANNEL_TYPES

      # @return [Array<Option>]
      attr_reader :options

      # @!visibility private
      def initialize
        @options = []
      end

      # @param name [String, Symbol] The name of the subcommand.
      # @param description [String] A description of the subcommand.
      # @yieldparam [OptionBuilder]
      # @return (see #add_option)
      def subcommand(name, description)
        builder = OptionBuilder.new
        yield builder if block_given?

        opt = Option.new(name, description, :subcommand)
        builder.options.each do |sub_opt|
          opt.subcommand(sub_opt.name, sub_opt.description, **sub_opt.attributes, &sub_opt.instance_variable_get(:@block))
        end
        @options << opt
        opt
      end

      def subcommand_group(name, description)
        builder = OptionBuilder.new
        yield builder if block_given?

        opt = Option.new(name, description, :subcommand_group)
        builder.options.each do |sub_opt|
          opt.subcommand(sub_opt.name, sub_opt.description, **sub_opt.attributes, &sub_opt.instance_variable_get(:@block))
        end
        @options << opt
        opt
      end

      def string(name, description, required: nil, min_length: nil, max_length: nil, choices: nil, autocomplete: nil,
                 name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        add_option(Option.new(name, description, :string,
                              required: required, min_length: min_length, max_length: max_length,
                              choices: choices, autocomplete: autocomplete,
                              name_localizations: name_localizations, description_localizations: description_localizations,
                              choice_localizations: choice_localizations))
      end

      def integer(name, description, required: nil, min_value: nil, max_value: nil, choices: nil, autocomplete: nil,
                  name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        add_option(Option.new(name, description, :integer,
                               required: required, min_value: min_value, max_value: max_value,
                               choices: choices, autocomplete: autocomplete,
                               name_localizations: name_localizations, description_localizations: description_localizations,
                               choice_localizations: choice_localizations))
      end

      def boolean(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        add_option(Option.new(name, description, :boolean, required: required,
                                                            name_localizations: name_localizations, description_localizations: description_localizations))
      end

      def user(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        add_option(Option.new(name, description, :user, required: required,
                                                        name_localizations: name_localizations, description_localizations: description_localizations))
      end

      def channel(name, description, required: nil, types: nil, name_localizations: nil, description_localizations: nil)
        add_option(Option.new(name, description, :channel, required: required, types: types,
                                                           name_localizations: name_localizations, description_localizations: description_localizations))
      end

      def role(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        add_option(Option.new(name, description, :role, required: required,
                                                        name_localizations: name_localizations, description_localizations: description_localizations))
      end

      def mentionable(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        add_option(Option.new(name, description, :mentionable, required: required,
                                                               name_localizations: name_localizations, description_localizations: description_localizations))
      end

      def number(name, description, required: nil, min_value: nil, max_value: nil, choices: nil, autocomplete: nil,
                 name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        add_option(Option.new(name, description, :number,
                              required: required, min_value: min_value, max_value: max_value,
                              choices: choices, autocomplete: autocomplete,
                              name_localizations: name_localizations, description_localizations: description_localizations,
                              choice_localizations: choice_localizations))
      end

      def attachment(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        add_option(Option.new(name, description, :attachment, required: required,
                                                               name_localizations: name_localizations, description_localizations: description_localizations))
      end

      # @!visibility private
      # Compat: aceita chamada direta com type integer
      def option(type, name, description, **attrs)
        type_sym = type.is_a?(Integer) ? TYPES.invert[type] : type
        add_option(Option.new(name, description, type_sym, **attrs))
      end

      # @return [Array<Hash>]
      def to_a
        @options.map(&:to_h)
      end

      # @return [Integer] número de opções
      def size
        @options.size
      end

      private

      def add_option(opt)
        @options << opt
        opt
      end

      # Convert Hash legacy para Option (compat)
      def to_option(hash_or_option)
        return hash_or_option if hash_or_option.is_a?(Option)

        type_sym = TYPES.invert[hash_or_option[:type]] || hash_or_option[:type]
        Option.new(hash_or_option[:name], hash_or_option[:description], type_sym,
                   required: hash_or_option[:required],
                   choices: hash_or_option[:choices],
                   min_value: hash_or_option[:min_value],
                   max_value: hash_or_option[:max_value],
                   min_length: hash_or_option[:min_length],
                   max_length: hash_or_option[:max_length],
                   channel_types: hash_or_option[:channel_types],
                   autocomplete: hash_or_option[:autocomplete],
                   name_localizations: hash_or_option[:name_localizations],
                   description_localizations: hash_or_option[:description_localizations])
      end
    end
  end
end
