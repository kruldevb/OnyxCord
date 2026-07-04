# frozen_string_literal: true

module OnyxCord
  module Interactions
    class Command
      attr_reader :name, :description, :type, :attributes, :options, :block

      TYPES = {
        chat_input: 1,
        user: 2,
        message: 3,
        primary_entry_point: 4
      }.freeze

      DESCRIPTION_TYPES = %i[chat_input primary_entry_point].freeze

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
        @type = type
        @attributes = attributes
        @options = []
        @block = block
        @executor = nil
        @default_member_permissions = attributes[:default_member_permissions]
        @nsfw = attributes[:nsfw]
        @contexts = attributes[:contexts]
        @dm_permission = attributes.fetch(:dm_permission, true)
        @name_localizations = attributes[:name_localizations]
        @description_localizations = attributes[:description_localizations]
        @integration_types = attributes[:integration_types]
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

      def to_h
        data = {
          name: @name,
          type: TYPES[@type] || @type
        }

        if DESCRIPTION_TYPES.include?(@type)
          data[:description] = @description
          data[:description_localizations] = @description_localizations if @description_localizations
        end

        data[:name_localizations] = @name_localizations if @name_localizations
        data[:options] = @options.map(&:to_h) unless @options.empty?
        data[:default_member_permissions] = @default_member_permissions.to_s if @default_member_permissions
        data[:dm_permission] = @dm_permission
        data[:nsfw] = @nsfw if @nsfw
        data[:contexts] = @contexts if @contexts
        data[:integration_types] = @integration_types if @integration_types

        data
      end

      Option::OPTION_METHODS.each do |method_name, option_type|
        define_method(method_name) do |name, description = '', **attrs, &blk|
          opt = Option.new(name, description, option_type, **attrs, &blk)
          @options << opt
          opt
        end
      end

      def subcommand(name, description, &block)
        sub = Option.new(name, description, :subcommand, &block)
        @options << sub
        sub
      end

      def subcommand_group(name, description, &block)
        group = Option.new(name, description, :subcommand_group, &block)
        @options << group
        group
      end

      def method_missing(method_name, *args, **kwargs, &block)
        if @block && @block.arity.positive?
          @block.call(Context::Proxy.new(self, method_name, args, kwargs, block))
        else
          super
        end
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end
    end
  end
end
