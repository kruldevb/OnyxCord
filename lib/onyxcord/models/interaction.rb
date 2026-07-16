# frozen_string_literal: true

require 'onyxcord/interactions/internal/application_command'
require 'onyxcord/interactions/internal/option_builder'
require 'onyxcord/interactions/internal/permission_builder'
require 'onyxcord/interactions/internal/message'
require 'onyxcord/interactions/internal/metadata'
require 'onyxcord/webhooks'
require 'onyxcord/internal/message_payload'

module OnyxCord
  # Base class for interaction objects.
  class Interaction
    include IDObject

    # Interaction types.
    # @see https://discord.com/developers/docs/interactions/slash-commands#interaction-interactiontype
    TYPES = {
      ping: 1,
      command: 2,
      component: 3,
      autocomplete: 4,
      modal_submit: 5
    }.freeze

    # Interaction response types.
    # @see https://discord.com/developers/docs/interactions/slash-commands#interaction-response-interactioncallbacktype
    CALLBACK_TYPES = {
      pong: 1,
      channel_message: 4,
      deferred_message: 5,
      deferred_update: 6,
      update_message: 7,
      autocomplete: 8,
      modal: 9
    }.freeze

    # Interaction context types.
    # @see https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-interaction-context-types
    CONTEXTS = {
      server: 0,
      bot_dm: 1,
      private_channel: 2
    }.freeze

    # Application integration types.
    # @see https://discord.com/developers/docs/resources/application#application-object-application-integration-types
    INTEGRATION_TYPES = {
      server: 0,
      user: 1
    }.freeze

    # Message flags for interaction responses.
    # @see https://discord.com/developers/docs/resources/message#message-object-message-flags
    FLAGS = {
      ephemeral: 1 << 6,
      suppress_embeds: 1 << 2,
      suppress_notifications: 1 << 12
    }.freeze

    # @return [User, Member] The user that initiated the interaction.
    attr_reader :user

    # @return [Integer, nil] The ID of the server this interaction originates from.
    attr_reader :server_id

    # @return [Integer] The ID of the channel this interaction originates from.
    attr_reader :channel_id

    # @return [Channel] The channel where this interaction originates from.
    attr_reader :channel

    # @return [Integer] The ID of the application associated with this interaction.
    attr_reader :application_id

    # @return [String] The interaction token.
    attr_reader :token

    # @!visibility private
    # @return [Integer] Currently pointless
    attr_reader :version

    # @return [Integer] The type of this interaction.
    # @see TYPES
    attr_reader :type

    # @return [Hash] The interaction data.
    attr_reader :data

    # @return [Interactions::Message, nil] The message associated with this interaction.
    attr_reader :message

    # @return [Array<ActionRow>] The modal components associated with this interaction.
    attr_reader :components

    # @return [Permissions] The permissions the application has where this interaction originates from.
    attr_reader :application_permissions

    # @return [String] The selected language of the user that initiated this interaction.
    attr_reader :user_locale

    # @return [String, nil] The selected language of the server this interaction originates from.
    attr_reader :server_locale

    # @return [Integer] The context of where this interaction was initiated from.
    attr_reader :context

    # @return [Integer] The maximum number of bytes an attachment can have when responding to this interaction.
    attr_reader :max_attachment_size

    # @return [Array<Symbol>] The features of the server where this interaction was initiated from.
    attr_reader :server_features

    # @!visibility private
    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @application_id = data['application_id'].to_i
      @type = data['type']
      @message = Interactions::Message.new(data['message'], @bot, self) if data['message']
      @data = data['data']
      @server_id = data['guild_id']&.to_i
      @channel_id = data['channel_id']&.to_i
      @channel = bot.ensure_channel(data['channel']) if data['channel']
      @user = begin
        if data['member'] && data['member']['user']
          member_data = data['member'].dup.merge('guild_id' => @server_id)
          server = bot.servers ? bot.servers[@server_id] : nil
          OnyxCord::Member.new(member_data, server, bot)
        elsif data['user']
          bot.ensure_user(data['user'])
        end
      rescue OnyxCord::Errors::OnyxCordError, NoMethodError, TypeError => e
        @bot.logger.error("Failed to parse interaction user/member: #{e.message}")
        nil
      end
      @token = data['token']
      @version = data['version']
      @data = data['data'] || {}
      @components = @data['components']&.filter_map { |component| Components.from_data(component, @bot) } || []
      @application_permissions = Permissions.new(data['app_permissions']) if data['app_permissions']
      @user_locale = data['locale']
      @server_locale = data['guild_locale']
      @context = data['context']
      @max_attachment_size = data['attachment_size_limit']
      @integration_owners = data['authorizing_integration_owners']&.to_h { |key, value| [key.to_i, value.to_i] }
      @server_features = data['guild'] ? data['guild']['features']&.map { |feature| feature.downcase.to_sym } : []
    end

    # Respond to the creation of this interaction. An interaction must be responded to or deferred,
    # The response may be modified with {Interaction#edit_response} or deleted with {Interaction#delete_response}.
    # Further messages can be sent with {Interaction#send_message}.
    # @param content [String] The content of the message.
    # @param tts [true, false]
    # @param embeds [Array<Hash, Webhooks::Embed>] The embeds for the message.
    # @param allowed_mentions [Hash, AllowedMentions] Mentions that can ping on this message.
    # @param flags [Integer] Message flags.
    # @param ephemeral [true, false] Whether this message should only be visible to the interaction initiator.
    # @param wait [true, false] Whether this method should return a Message object of the interaction response.
    # @param components [Array<#to_h>] An array of components.
    # @param attachments [Array<File>] Files that can be referenced in embeds and components via `attachment://file.png`.
    # @param has_components [true, false] Whether this message includes any V2 components. Enabling this disables sending content, polls, and embeds.
    # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
    # @yieldparam builder [Webhooks::Builder] An optional message builder. Arguments passed to the method overwrite builder data.
    # @yieldparam view [Webhooks::View] A builder for creating interaction components.
    def respond(content: nil, tts: nil, embeds: nil, allowed_mentions: nil, flags: 0, ephemeral: nil, suppress_embeds: nil, suppress_notifications: nil, wait: false, components: nil, attachments: nil, has_components: false, components_v2: false, poll: nil)
      flags |= FLAGS[:ephemeral] if ephemeral
      flags |= FLAGS[:suppress_embeds] if suppress_embeds
      flags |= FLAGS[:suppress_notifications] if suppress_notifications

      builder = OnyxCord::Webhooks::Builder.new
      view = OnyxCord::Webhooks::View.new

      # Set builder defaults from parameters
      prepare_builder(builder, content, embeds, allowed_mentions, poll)
      yield(builder, view) if block_given?

      components ||= view
      flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components, force: has_components || components_v2)
      data = builder.to_json_hash

      response = OnyxCord::REST::Interaction.create_interaction_response(@token, @id, CALLBACK_TYPES[:channel_message], data[:content], tts, data[:embeds], data[:allowed_mentions], flags, components.to_a, attachments, nil, wait, data[:poll])
      return unless wait

      Interactions::Message.new(JSON.parse(response)['resource']['message'], @bot, self)
    end

    # Defer an interaction, setting a temporary response that can be later overriden by {Interaction#send_message}.
    # This method is used when you want to use a single message for your response but require additional processing time, or to simply ack
    # an interaction so an error is not displayed.
    # @param flags [Integer] Message flags.
    # @param ephemeral [true, false] Whether this message should only be visible to the interaction initiator.
    def defer(flags: 0, ephemeral: true, suppress_embeds: nil, suppress_notifications: nil)
      flags |= FLAGS[:ephemeral] if ephemeral
      flags |= FLAGS[:suppress_embeds] if suppress_embeds
      flags |= FLAGS[:suppress_notifications] if suppress_notifications

      OnyxCord::REST::Interaction.create_interaction_response(@token, @id, CALLBACK_TYPES[:deferred_message], nil, nil, nil, nil, flags)
      nil
    end

    # Defer an update to an interaction. This is can only currently used by Button interactions.
    def defer_update
      OnyxCord::REST::Interaction.create_interaction_response(@token, @id, CALLBACK_TYPES[:deferred_update])
    end

    # Create a modal as a response.
    # @param title [String] The title of the modal being shown.
    # @param custom_id [String] The custom_id used to identify the modal and store data.
    # @param components [Array<Component, Hash>, nil] An array of components. These can be defined through the block as well.
    # @yieldparam [OnyxCord::Webhooks::Modal] A builder for the modal's components.
    def show_modal(title:, custom_id:, components: nil)
      if block_given?
        modal_builder = OnyxCord::Webhooks::Modal.new
        yield modal_builder

        components = modal_builder.to_a
      end

      OnyxCord::REST::Interaction.create_interaction_modal_response(@token, @id, custom_id, title, components.to_a) unless type == Interaction::TYPES[:modal_submit]
      nil
    end

    # Respond to the creation of this interaction. An interaction must be responded to or deferred,
    # The response may be modified with {Interaction#edit_response} or deleted with {Interaction#delete_response}.
    # Further messages can be sent with {Interaction#send_message}.
    # @param content [String] The content of the message.
    # @param tts [true, false]
    # @param embeds [Array<Hash, Webhooks::Embed>] The embeds for the message.
    # @param allowed_mentions [Hash, AllowedMentions] Mentions that can ping on this message.
    # @param flags [Integer] Message flags.
    # @param ephemeral [true, false] Whether this message should only be visible to the interaction initiator.
    # @param wait [true, false] Whether this method should return a Message object of the interaction response.
    # @param components [Array<#to_h>] An array of components.
    # @param attachments [Array<File>] Files that can be referenced in embeds and components via `attachment://file.png`.
    # @param has_components [true, false] Whether this message includes any V2 components. Enabling this disables sending content, polls, and embeds.
    # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
    # @yieldparam builder [Webhooks::Builder] An optional message builder. Arguments passed to the method overwrite builder data.
    # @yieldparam view [Webhooks::View] A builder for creating interaction components.
    def update_message(content: nil, tts: nil, embeds: nil, allowed_mentions: nil, flags: 0, ephemeral: nil, suppress_embeds: nil, suppress_notifications: nil, wait: false, components: nil, attachments: nil, has_components: false, components_v2: false, poll: nil)
      flags |= FLAGS[:ephemeral] if ephemeral
      flags |= FLAGS[:suppress_embeds] if suppress_embeds
      flags |= FLAGS[:suppress_notifications] if suppress_notifications

      builder = OnyxCord::Webhooks::Builder.new
      view = OnyxCord::Webhooks::View.new

      prepare_builder(builder, content, embeds, allowed_mentions, poll)
      yield(builder, view) if block_given?

      components ||= view
      flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components, force: has_components || components_v2)
      data = builder.to_json_hash

      response = OnyxCord::REST::Interaction.create_interaction_response(@token, @id, CALLBACK_TYPES[:update_message], data[:content], tts, data[:embeds], data[:allowed_mentions], flags, components.to_a, attachments, nil, wait, data[:poll])
      return unless wait

      Interactions::Message.new(JSON.parse(response)['resource']['message'], @bot, self)
    end

    # Edit the original response to this interaction.
    # @param content [String] The content of the message.
    # @param embeds [Array<Hash, Webhooks::Embed>] The embeds for the message.
    # @param allowed_mentions [Hash, AllowedMentions] Mentions that can ping on this message.
    # @param flags [Integer] Message flags.
    # @param components [Array<#to_h>] An array of components.
    # @param attachments [Array<File>] Files that can be referenced in embeds and components via `attachment://file.png`.
    # @param has_components [true, false] Whether this message includes any V2 components. Enabling this disables sending content, polls, and embeds.
    # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
    # @return [InteractionMessage] The updated response message.
    # @yieldparam builder [Webhooks::Builder] An optional message builder. Arguments passed to the method overwrite builder data.
    def edit_response(content: nil, embeds: nil, allowed_mentions: nil, flags: 0, components: nil, attachments: nil, has_components: false, components_v2: false, poll: nil)
      builder = OnyxCord::Webhooks::Builder.new
      view = OnyxCord::Webhooks::View.new

      prepare_builder(builder, content, embeds, allowed_mentions, poll)
      yield(builder, view) if block_given?

      components ||= view
      flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components, force: has_components || components_v2)
      data = builder.to_json_hash
      resp = OnyxCord::REST::Interaction.edit_original_interaction_response(@token, @application_id, edit_content(content, data), edit_embeds(embeds, data), data[:allowed_mentions], components.to_a, attachments, flags, data[:poll])

      Interactions::Message.new(JSON.parse(resp), @bot, self)
    end

    # Delete the original interaction response.
    def delete_response
      OnyxCord::REST::Interaction.delete_original_interaction_response(@token, @application_id)
    end

    # @param content [String] The content of the message.
    # @param tts [true, false]
    # @param embeds [Array<Hash, Webhooks::Embed>] The embeds for the message.
    # @param allowed_mentions [Hash, AllowedMentions] Mentions that can ping on this message.
    # @param flags [Integer] Message flags.
    # @param ephemeral [true, false] Whether this message should only be visible to the interaction initiator.
    # @param attachments [Array<File>] Files that can be referenced in embeds and components via `attachment://file.png`.
    # @param has_components [true, false] Whether this message includes any V2 components. Enabling this disables sending content, polls, and embeds.
    # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
    # @yieldparam builder [Webhooks::Builder] An optional message builder. Arguments passed to the method overwrite builder data.
    # @yieldparam view [Webhooks::View] A builder for creating interaction components.
    def send_message(content: nil, embeds: nil, tts: false, allowed_mentions: nil, flags: 0, ephemeral: false, suppress_embeds: nil, suppress_notifications: nil, components: nil, attachments: nil, has_components: false, components_v2: false, poll: nil)
      flags |= FLAGS[:ephemeral] if ephemeral
      flags |= FLAGS[:suppress_embeds] if suppress_embeds
      flags |= FLAGS[:suppress_notifications] if suppress_notifications

      builder = OnyxCord::Webhooks::Builder.new
      view = OnyxCord::Webhooks::View.new

      prepare_builder(builder, content, embeds, allowed_mentions, poll)
      yield(builder, view) if block_given?

      components ||= view
      flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components, force: has_components || components_v2)
      data = builder.to_json_hash

      resp = OnyxCord::REST::Webhook.token_execute_webhook(
        @token, @application_id, true, data[:content], nil, nil, tts, nil, data[:embeds], data[:allowed_mentions], flags, components.to_a, attachments, data[:poll]
      )
      Interactions::Message.new(JSON.parse(resp), @bot, self)
    end

    alias edit_original edit_response
    alias delete_original delete_response
    alias followup send_message

    # @param message [String, Integer, InteractionMessage, Message] The message created by this interaction to be edited.
    # @param content [String] The message content.
    # @param embeds [Array<Hash, Webhooks::Embed>] The embeds for the message.
    # @param allowed_mentions [Hash, AllowedMentions] Mentions that can ping on this message.
    # @param attachments [Array<File>] Files that can be referenced in embeds via `attachment://file.png`.
    # @param flags [Integer] Message flags.
    # @param has_components [true, false] Whether this message includes any V2 components. Enabling this disables sending content, polls, and embeds.
    # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
    # @yieldparam builder [Webhooks::Builder] An optional message builder. Arguments passed to the method overwrite builder data.
    def edit_message(message, content: nil, embeds: nil, allowed_mentions: nil, components: nil, attachments: nil, flags: 0, has_components: false, components_v2: false, poll: nil)
      builder = OnyxCord::Webhooks::Builder.new
      view = OnyxCord::Webhooks::View.new

      prepare_builder(builder, content, embeds, allowed_mentions, poll)
      yield(builder, view) if block_given?

      components ||= view
      flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components, force: has_components || components_v2)
      data = builder.to_json_hash

      resp = OnyxCord::REST::Webhook.token_edit_message(
        @token, @application_id, message.resolve_id, edit_content(content, data), edit_embeds(embeds, data), data[:allowed_mentions], components.to_a, attachments, flags, data[:poll]
      )
      Interactions::Message.new(JSON.parse(resp), @bot, self)
    end

    # @param message [Integer, String, InteractionMessage, Message] The message created by this interaction to be deleted.
    def delete_message(message)
      OnyxCord::REST::Webhook.token_delete_message(@token, @application_id, message.resolve_id)
      nil
    end

    # Show autocomplete choices as a response.
    # @param choices [Array<Hash>, Hash] Array of autocomplete choices to show the user.
    def show_autocomplete_choices(choices)
      choices = choices.map { |name, value| { name: name, value: value } } unless choices.is_a?(Array)
      OnyxCord::REST::Interaction.create_interaction_response(@token, @id, CALLBACK_TYPES[:autocomplete], nil, nil, nil, nil, nil, nil, nil, choices)
      nil
    end

    # Get the server associated with the interaction.
    # @return [Server, nil] This will be nil for interactions that occur in DM channels or servers where the bot
    #   does not have the `bot` scope.
    def server
      @bot.server(@server_id)
    end

    # Get the button component that triggered the interaction.
    # @return [Components::Button, nil] The button that triggered this interaction if applicable, otherwise `nil`.
    def button
      @type == TYPES[:component] ? get_component(@data['custom_id']) : nil
    end

    # Get the text input components associated with the interaction.
    # @return [Array<TextInput>] The text input components associated with this interaction.
    def text_inputs
      @components.filter_map do |entity|
        entity.component if entity.is_a?(Components::Label) && entity.component.is_a?(Components::TextInput)
      end
    end

    # Get a component by its custom ID.
    # @param custom_id [String] the custom ID of the component to find.
    # @return [TextInput, Button, SelectMenu, Checkbox, ModalActionGroup, nil] The component associated with the custom ID, or `nil`.
    def get_component(custom_id)
      components = flatten_components((@message&.components || []) + @components)
      components.find { |component| component.respond_to?(:custom_id) && component.custom_id == custom_id }
    end

    # @return [true, false] whether the application was installed by the user who initiated this interaction.
    def user_integration?
      return false unless @user
      return false unless @integration_owners

      @integration_owners[1] == @user.id
    end

    # @return [true, false] whether the application was installed by the server where this interaction originates from.
    def server_integration?
      return false unless @server_id
      return false unless @integration_owners

      @integration_owners[0] == @server_id
    end

    # The inspect method does not expose the interaction token.
    def inspect
      "<Interaction type=#{@type} id=#{@id}>"
    end

    private

    # Set builder defaults from parameters
    # @param builder [OnyxCord::Webhooks::Builder]
    # @param content [String, nil]
    # @param embeds [Array<Hash, OnyxCord::Webhooks::Embed>, nil]
    # @param allowed_mentions [AllowedMentions, Hash, nil]
    # @param poll [Poll, Poll::Builder, Hash, nil]
    def prepare_builder(builder, content, embeds, allowed_mentions, poll)
      builder.poll = poll
      builder.content = content unless content == OnyxCord::MessagePayload::KEEP
      builder.allowed_mentions = allowed_mentions
      embeds&.each { |embed| builder << embed } unless embeds == OnyxCord::MessagePayload::KEEP
    end

    def edit_content(content, data)
      content == OnyxCord::MessagePayload::KEEP ? OnyxCord::MessagePayload::KEEP : data[:content]
    end

    def edit_embeds(embeds, data)
      embeds == OnyxCord::MessagePayload::KEEP ? OnyxCord::MessagePayload::KEEP : data[:embeds]
    end

    # @!visibility private
    def flatten_components(components)
      components = components.flat_map do |entity|
        case entity
        when Components::ActionRow
          entity.components
        when Components::Label
          entity.component
        when Components::Section
          entity.accessory if entity.accessory.respond_to?(:custom_id)
        when Components::Container
          flatten_components(entity.components)
        else
          entity if entity.respond_to?(:custom_id)
        end
      end

      components.compact
    end
  end
end
