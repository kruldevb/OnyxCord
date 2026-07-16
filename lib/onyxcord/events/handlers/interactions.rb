# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised whenever an interaction event is received.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer, Symbol, String] :type The interaction type, can be the integer value or the name
    #   of the key in {OnyxCord::Interaction::TYPES}.
    # @option attributes [String, Integer, Server, nil] :server The server where this event was created. `nil` for DM channels.
    # @option attributes [String, Integer, Channel] :channel The channel where this event was created.
    # @option attributes [String, Integer, User] :user The user that triggered this event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [InteractionCreateEvent] The event that was raised.
    # @return [InteractionCreateEventHandler] The event handler that was registered.
    def interaction_create(attributes = {}, &block)
      register_event(InteractionCreateEvent, attributes, block)
    end

    # This **event** is raised whenever an application command (slash command) is executed.
    # @param name [Symbol, String] The name of the application command this handler is for.
    # @param attributes [Hash] The event's attributes.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ApplicationCommandEvent] The event that was raised.
    # @return [ApplicationCommandEventHandler] The event handler that was registered.

    # This **event** is raised whenever an application command (slash command) is executed.
    # @param name [Symbol, String] The name of the application command this handler is for.
    # @param attributes [Hash] The event's attributes.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ApplicationCommandEvent] The event that was raised.
    # @return [ApplicationCommandEventHandler] The event handler that was registered.
    def application_command(name, attributes = {}, &block)
      name = name.to_sym
      @application_commands ||= {}

      unless block
        @application_commands[name] ||= ApplicationCommandEventHandler.new(attributes, nil)
        return @application_commands[name]
      end

      @application_commands[name] = ApplicationCommandEventHandler.new(attributes, block)
    end

    # This **event** is raised whenever an button interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ButtonEvent] The event that was raised.
    # @return [ButtonEventHandler] The event handler that was registered.

    # This **event** is raised whenever an button interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ButtonEvent] The event that was raised.
    # @return [ButtonEventHandler] The event handler that was registered.
    def button(attributes = {}, &block)
      register_event(ButtonEvent, attributes, block)
    end

    # This **event** is raised whenever an select string interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [StringSelectEvent] The event that was raised.
    # @return [StringSelectEventHandler] The event handler that was registered.

    # This **event** is raised whenever an select string interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [StringSelectEvent] The event that was raised.
    # @return [StringSelectEventHandler] The event handler that was registered.
    def string_select(attributes = {}, &block)
      register_event(StringSelectEvent, attributes, block)
    end

    alias_method :select_menu, :string_select

    # This **event** is raised whenever a modal is submitted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @option attributes [String, Integer, Server, nil] :server The server where this event was created. `nil` for DM channels.
    # @option attributes [String, Integer, Channel] :channel The channel where this event was created.
    # @option attributes [String, Integer, User] :user The user that triggered this event.    # @yield The block is executed when the event is raised.
    # @yieldparam event [ModalSubmitEvent] The event that was raised.
    # @return [ModalSubmitEventHandler] The event handler that was registered.

    # This **event** is raised whenever a modal is submitted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @option attributes [String, Integer, Server, nil] :server The server where this event was created. `nil` for DM channels.
    # @option attributes [String, Integer, Channel] :channel The channel where this event was created.
    # @option attributes [String, Integer, User] :user The user that triggered this event.    # @yield The block is executed when the event is raised.
    # @yieldparam event [ModalSubmitEvent] The event that was raised.
    # @return [ModalSubmitEventHandler] The event handler that was registered.
    def modal_submit(attributes = {}, &block)
      register_event(ModalSubmitEvent, attributes, block)
    end

    # This **event** is raised whenever an select user interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserSelectEvent] The event that was raised.
    # @return [UserSelectEventHandler] The event handler that was registered.

    # This **event** is raised whenever an select user interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserSelectEvent] The event that was raised.
    # @return [UserSelectEventHandler] The event handler that was registered.
    def user_select(attributes = {}, &block)
      register_event(UserSelectEvent, attributes, block)
    end

    # This **event** is raised whenever an select role interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [RoleSelectEvent] The event that was raised.
    # @return [RoleSelectEventHandler] The event handler that was registered.

    # This **event** is raised whenever an select role interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [RoleSelectEvent] The event that was raised.
    # @return [RoleSelectEventHandler] The event handler that was registered.
    def role_select(attributes = {}, &block)
      register_event(RoleSelectEvent, attributes, block)
    end

    # This **event** is raised whenever an select mentionable interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MentionableSelectEvent] The event that was raised.
    # @return [MentionableSelectEventHandler] The event handler that was registered.

    # This **event** is raised whenever an select mentionable interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MentionableSelectEvent] The event that was raised.
    # @return [MentionableSelectEventHandler] The event handler that was registered.
    def mentionable_select(attributes = {}, &block)
      register_event(MentionableSelectEvent, attributes, block)
    end

    # This **event** is raised whenever an select channel interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelSelectEvent] The event that was raised.
    # @return [ChannelSelectEventHandler] The event handler that was registered.

    # This **event** is raised whenever an select channel interaction is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :custom_id A custom_id to match against.
    # @option attributes [String, Integer, Message] :message The message to filter for.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelSelectEvent] The event that was raised.
    # @return [ChannelSelectEventHandler] The event handler that was registered.
    def channel_select(attributes = {}, &block)
      register_event(ChannelSelectEvent, attributes, block)
    end

    # This **event** is raised whenever a message is pinned or unpinned.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :channel A channel to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelPinsUpdateEvent] The event that was raised.
    # @return [ChannelPinsUpdateEventHandler] The event handler that was registered.

    # This **event** is raised whenever an autocomplete interaction is created.
    # @param name [String, Symbol, nil] An option name to match against.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :command_id A command ID to match against.
    # @option attributes [String, Symbol] :subcommand A subcommand name to match against.
    # @option attributes [String, Symbol] :subcommand_group A subcommand group to match against.
    # @option attributes [String, Symbol] :command_name A command name to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AutocompleteEvent] The event that was raised.
    # @return [AutocompleteEventHandler] The event handler that was registered.
    def autocomplete(name = nil, attributes = {}, &block)
      register_event(AutocompleteEvent, attributes.merge({ name: name&.to_s }), block)
    end

    # This **event** is raised whenever an application command's permissions are updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :command_id A command ID to match against.
    # @option attributes [String, Integer] :application_id An application ID to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ApplicationCommandPermissionsUpdateEvent] The event that was raised.
    # @return [ApplicationCommandPermissionsUpdateEventHandler] The event handler that was registered.

    # This **event** is raised whenever an application command's permissions are updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :command_id A command ID to match against.
    # @option attributes [String, Integer] :application_id An application ID to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ApplicationCommandPermissionsUpdateEvent] The event that was raised.
    # @return [ApplicationCommandPermissionsUpdateEventHandler] The event handler that was registered.
    def application_command_permissions_update(attributes = {}, &block)
      register_event(ApplicationCommandPermissionsUpdateEvent, attributes, block)
    end

    # This **event** is raised whenever a user votes on a poll.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User, Member] :user A user to match against.
    # @option attributes [String, Integer, Channel] :channel A channel to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Message] :message A message to match against.
    # @option attributes [String, Integer, Answer] :answer A poll answer to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PollVoteAddEvent] The event that was raised.
    # @return [PollVoteAddEventHandler] The event handler that was registered.
  end
end
