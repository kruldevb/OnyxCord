# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Generic subclass for interaction events
  class InteractionCreateEvent < Event
    # Struct to allow accessing data via [] or methods.
    Resolved = Struct.new('Resolved', :channels, :members, :messages, :roles, :users, :attachments) # rubocop:disable Lint/StructNewOverride

    # @return [Interaction] The interaction for this event.
    attr_reader :interaction

    # @!attribute [r] type
    #   @return [Integer]
    #   @see Interaction#type
    # @!attribute [r] server
    #   @return [Server, nil]
    #   @see Interaction#server
    # @!attribute [r] server_id
    #   @return [Integer]
    #   @see Interaction#server_id
    # @!attribute [r] channel
    #   @return [Channel]
    #   @see Interaction#channel
    # @!attribute [r] channel_id
    #   @return [Integer]
    #   @see Interaction#channel_id
    # @!attribute [r] user
    #   @return [User]
    #   @see Interaction#user
    # @!attribute [r] user_locale
    #   @return [String]
    #   @see Interaction#user_locale
    # @!attribute [r] context
    #   @return [Integer]
    #   @see Interaction#context
    # @!attribute [r] user_integration?
    #   @return [true, false]
    #   @see Interaction#user_integration?
    # @!attribute [r] server_integration?
    #   @return [true, false]
    #   @see Interaction#server_integration?
    delegate :type, :server, :server_id, :channel, :channel_id, :user, :user_locale, :context, :user_integration?, :server_integration?, to: :interaction

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @interaction = OnyxCord::Interaction.new(data, @bot)
    end

    # @see Interaction#respond
    def respond(...)
      @interaction.respond(...)
    end

    # @see Interaction#defer
    def defer(...)
      @interaction.defer(...)
    end

    # @see Interaction#update_message
    def update_message(...)
      @interaction.update_message(...)
    end

    # @see Interaction#show_modal
    def show_modal(...)
      @interaction.show_modal(...)
    end

    # @see Interaction#edit_response
    def edit_response(...)
      @interaction.edit_response(...)
    end

    # @see Interaction#delete_response
    def delete_response
      @interaction.delete_response
    end

    # @see Interaction#send_message
    def send_message(...)
      @interaction.send_message(...)
    end

    # @see Interaction#edit_message
    def edit_message(...)
      @interaction.edit_message(...)
    end

    # @see Interaction#delete_message
    def delete_message(...)
      @interaction.delete_message(...)
    end

    # @see Interaction#defer_update
    def defer_update
      @interaction.defer_update
    end

    # @see Interaction#get_component
    def get_component(...)
      @interaction.get_component(...)
    end

    private

    # @!visibility private
    def process_resolved(resolved_data)
      resolved_data['users']&.each do |id, data|
        @resolved[:users][id.to_i] = @bot.ensure_user(data)
      end

      resolved_data['roles']&.each do |id, data|
        @resolved[:roles][id.to_i] = OnyxCord::Role.new(data, @bot)
      end

      resolved_data['channels']&.each do |id, data|
        data['guild_id'] = @interaction.server_id
        @resolved[:channels][id.to_i] = OnyxCord::Channel.new(data, @bot)
      end

      resolved_data['members']&.each do |id, data|
        data['user'] = resolved_data['users'][id]
        data['guild_id'] = @interaction.server_id
        @resolved[:members][id.to_i] = OnyxCord::Member.new(data, nil, @bot)
      end

      resolved_data['messages']&.each do |id, data|
        @resolved[:messages][id.to_i] = OnyxCord::Message.new(data, @bot)
      end

      resolved_data['attachments']&.each do |id, data|
        @resolved[:attachments][id.to_i] = OnyxCord::Attachment.new(data, nil, @bot)
      end
    end
  end

  # Event handler for INTERACTION_CREATE events.

  # Event handler for INTERACTION_CREATE events.
  class InteractionCreateEventHandler < EventHandler
    # @!visibility private
    def matches?(event)
      return false unless event.is_a? InteractionCreateEvent

      [
        matches_all(@attributes[:type], event.type) do |a, e|
          a == case a
               when String, Symbol
                 OnyxCord::Interactions::TYPES[e.to_sym]
               else
                 e
               end
        end,

        matches_all(@attributes[:server], event.interaction) do |a, e|
          a.resolve_id == e.server_id
        end,

        matches_all(@attributes[:channel], event.interaction) do |a, e|
          a.resolve_id == e.channel_id
        end,

        matches_all(@attributes[:user], event.user) do |a, e|
          a.resolve_id == e.id
        end
      ].reduce(true, &:&)
    end
  end

  # Event for ApplicationCommand interactions.
end
