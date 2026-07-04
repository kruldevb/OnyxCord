# frozen_string_literal: true

module OnyxCord
  module Interactions
    # A builder for defining slash commands options.
    class OptionBuilder
      # @!visibility private
      TYPES = {
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

      # Channel types that can be provided to #channel
      CHANNEL_TYPES = {
        text: 0,
        dm: 1,
        voice: 2,
        group_dm: 3,
        category: 4,
        news: 5,
        store: 6,
        news_thread: 10,
        public_thread: 11,
        private_thread: 12,
        stage: 13
      }.freeze

      # @return [Array<Hash>]
      attr_reader :options

      # @!visibility private
      def initialize
        @options = []
      end

      # @param name [String, Symbol] The name of the subcommand.
      # @param description [String] A description of the subcommand.
      # @yieldparam [OptionBuilder]
      # @return (see #option)
      # @example
      #   bot.register_application_command(:test, 'Test command') do |cmd|
      #     cmd.subcommand(:echo) do |sub|
      #       sub.string('message', 'What to echo back', required: true)
      #     end
      #   end
      def subcommand(name, description)
        builder = OptionBuilder.new
        yield builder if block_given?

        option(TYPES[:subcommand], name, description, options: builder.to_a)
      end

      # @param name [String, Symbol] The name of the subcommand group.
      # @param description [String] A description of the subcommand group.
      # @yieldparam [OptionBuilder]
      # @return (see #option)
      # @example
      #   bot.register_application_command(:test, 'Test command') do |cmd|
      #     cmd.subcommand_group(:fun) do |group|
      #       group.subcommand(:8ball) do |sub|
      #         sub.string(:question, 'What do you ask the mighty 8ball?')
      #       end
      #     end
      #   end
      def subcommand_group(name, description)
        builder = OptionBuilder.new
        yield builder

        option(TYPES[:subcommand_group], name, description, options: builder.to_a)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @param min_length [Integer] A minimum length for option value.
      # @param max_length [Integer] A maximum length for option value.
      # @param choices [Hash, nil] Available choices, mapped as `Name => Value`.
      # @param autocomplete [true, false] Whether this option can dynamically show choices.
      # @return (see #option)
      def string(name, description, required: nil, min_length: nil, max_length: nil, choices: nil, autocomplete: nil,
                 name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        option(TYPES[:string], name, description,
               required: required, min_length: min_length, max_length: max_length, choices: choices, autocomplete: autocomplete,
               name_localizations: name_localizations, description_localizations: description_localizations,
               choice_localizations: choice_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @param min_value [Integer] A minimum value for option.
      # @param max_value [Integer] A maximum value for option.
      # @param choices [Hash, nil] Available choices, mapped as `Name => Value`.
      # @param autocomplete [true, false] Whether this option can dynamically show choices.
      # @return (see #option)
      def integer(name, description, required: nil, min_value: nil, max_value: nil, choices: nil, autocomplete: nil,
                  name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        option(TYPES[:integer], name, description,
               required: required, min_value: min_value, max_value: max_value, choices: choices, autocomplete: autocomplete,
               name_localizations: name_localizations, description_localizations: description_localizations,
               choice_localizations: choice_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @return (see #option)
      def boolean(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        option(TYPES[:boolean], name, description, required: required,
                                                   name_localizations: name_localizations, description_localizations: description_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @return (see #option)
      def user(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        option(TYPES[:user], name, description, required: required,
                                                name_localizations: name_localizations, description_localizations: description_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @param types [Array<Symbol, Integer>] See {CHANNEL_TYPES}
      # @return (see #option)
      def channel(name, description, required: nil, types: nil, name_localizations: nil, description_localizations: nil)
        types = types&.collect { |type| type.is_a?(Numeric) ? type : CHANNEL_TYPES[type] }
        option(TYPES[:channel], name, description, required: required, channel_types: types,
                                                   name_localizations: name_localizations, description_localizations: description_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @return (see #option)
      def role(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        option(TYPES[:role], name, description, required: required,
                                                name_localizations: name_localizations, description_localizations: description_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @return (see #option)
      def mentionable(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        option(TYPES[:mentionable], name, description, required: required,
                                                       name_localizations: name_localizations, description_localizations: description_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @param min_value [Float] A minimum value for option.
      # @param max_value [Float] A maximum value for option.
      # @param autocomplete [true, false] Whether this option can dynamically show choices.
      # @return (see #option)
      def number(name, description, required: nil, min_value: nil, max_value: nil, choices: nil, autocomplete: nil,
                 name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        option(TYPES[:number], name, description,
               required: required, min_value: min_value, max_value: max_value, choices: choices, autocomplete: autocomplete,
               name_localizations: name_localizations, description_localizations: description_localizations,
               choice_localizations: choice_localizations)
      end

      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @return (see #option)
      def attachment(name, description, required: nil, name_localizations: nil, description_localizations: nil)
        option(TYPES[:attachment], name, description, required: required,
                                                      name_localizations: name_localizations, description_localizations: description_localizations)
      end

      # @!visibility private
      # @param type [Integer] The argument type.
      # @param name [String, Symbol] The name of the argument.
      # @param description [String] A description of the argument.
      # @param required [true, false] Whether this option must be provided.
      # @param min_value [Integer, Float] A minimum value for integer and number options.
      # @param max_value [Integer, Float] A maximum value for integer and number options.
      # @param min_length [Integer] A minimum length for string option value.
      # @param max_length [Integer] A maximum length for string option value.
      # @param channel_types [Array<Integer>] Channel types that can be provides for channel options.
      # @param autocomplete [true, false] Whether this option can dynamically show options.
      # @return Hash
      def option(type, name, description, required: nil, choices: nil, options: nil, min_value: nil, max_value: nil,
                 min_length: nil, max_length: nil, channel_types: nil, autocomplete: nil,
                 name_localizations: nil, description_localizations: nil, choice_localizations: nil)
        opt = { type: type, name: name, description: description }
        choices = build_choices(choices, choice_localizations) if choices

        opt.merge!({ required: required, choices: choices, options: options, min_value: min_value,
                     max_value: max_value, min_length: min_length, max_length: max_length,
                     channel_types: channel_types, autocomplete: autocomplete,
                     name_localizations: name_localizations, description_localizations: description_localizations }.compact)

        @options << opt
        opt
      end

      # @return [Array<Hash>]
      def to_a
        @options
      end

      private

      def build_choices(choices, choice_localizations)
        choices.map do |option_name, value|
          choice = { name: option_name, value: value }
          if choice_localizations&.key?(option_name.to_sym) || choice_localizations&.key?(option_name.to_s)
            locs = choice_localizations[option_name.to_sym] || choice_localizations[option_name.to_s]
            choice[:name_localizations] = locs if locs.is_a?(Hash)
          end
          choice
        end
      end
    end
  end
end
