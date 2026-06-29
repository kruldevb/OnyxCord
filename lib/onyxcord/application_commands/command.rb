# frozen_string_literal: true

module OnyxCord
  module ApplicationCommands
    class Command
      attr_reader :name, :description, :type, :attributes, :options, :block

      TYPES = {
        chat_input: 1,
        user: 2,
        message: 3
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

        data[:description] = @description if @type == :chat_input
        data[:options] = @options.map(&:to_h) unless @options.empty?
        data[:default_member_permissions] = @default_member_permissions if @default_member_permissions
        data[:nsfw] = @nsfw if @nsfw
        data[:contexts] = @contexts if @contexts

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

      def respond_to_missing?(method_name, include_private = false)
        true
      end
    end
  end
end