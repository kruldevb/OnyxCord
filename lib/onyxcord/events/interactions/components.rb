# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # An event for when a user interacts with a component.
  class ComponentEvent < InteractionCreateEvent
    # @return [String] User provided data for this button.
    attr_reader :custom_id

    # @return [Interactions::Message, nil] The message the button originates from.
    attr_reader :message

    # @!visibility private
    def initialize(data, bot)
      super

      @message = @interaction.message
      @custom_id = data['data']['custom_id']
    end
  end

  # Generic handler for component events.

  # Generic handler for component events.
  class ComponentEventHandler < InteractionCreateEventHandler
    def matches?(event)
      return false unless super
      return false unless event.is_a? ComponentEvent

      [
        matches_all(@attributes[:custom_id], event.custom_id) do |a, e|
          # Match regexp and strings
          case a
          when Regexp
            a.match?(e)
          else
            a == e
          end
        end,
        matches_all(@attributes[:message], event.message) do |a, e|
          case a
          when String, Integer
            a.resolve_id == e.id
          else
            a.id == e.id
          end
        end
      ].reduce(&:&)
    end
  end

  # An event for when a user interacts with a button component.

  # An event for when a user interacts with a button component.
  class ButtonEvent < ComponentEvent
  end

  # Event handler for a Button interaction event.

  # Event handler for a Button interaction event.
  class ButtonEventHandler < ComponentEventHandler
  end

  # Event for when a user interacts with a select string component.

  # Event for when a user interacts with a select string component.
  class StringSelectEvent < ComponentEvent
    # @return [Array<String>] Selected values.
    attr_reader :values

    # @!visibility private
    def initialize(data, bot)
      super

      @values = data['data']['values']
    end
  end

  # Event handler for a select string component.

  # Event handler for a select string component.
  class StringSelectEventHandler < ComponentEventHandler
  end

  # An event for when a user submits a modal.

  # An event for when a user submits a modal.
  class ModalSubmitEvent < ComponentEvent
    # @return [Array<Component>] an array of partial component objects that were in the modal.
    attr_reader :components

    # @return [Resolved] The resolved channels, roles, users, members, and attachments for the modal.
    attr_reader :resolved

    # @!visibility private
    def initialize(data, bot)
      super

      @components = @interaction.components
      @resolved = Resolved.new({}, {}, {}, {}, {}, {})
      process_resolved(data['data']['resolved']) if data['data']['resolved']
    end

    # Get the value of an input passed to the modal.
    # @param custom_id [String] The custom ID of the component to look for.
    # @return [String, nil] The selected value for the component.
    def value(custom_id)
      get_component(custom_id)&.value
    end

    # Get the selected values from a select menu or file upload component.
    # @param custom_id [String] The custom ID of the component to look for.
    # @return [Array<String>, nil] The values that were chosen for the component.
    def values(custom_id)
      get_component(custom_id)&.values
    end

    # Get the attachments that a user uploaded in this modal.
    # @param custom_id [String] The custom ID of the file upload component to get attachments for.
    # @return [Array<Attachment>] the attachments that were uploaded to the file upload component.
    def attachments(custom_id)
      values(custom_id)&.map { |id| @resolved[:attachments][id.to_i] } || []
    end
  end

  # Event handler for a modal submission.

  # Event handler for a modal submission.
  class ModalSubmitEventHandler < ComponentEventHandler
  end

  # Event for when a user interacts with a select user component.

  # Event for when a user interacts with a select user component.
  class UserSelectEvent < ComponentEvent
    # @return [Array<User>] Selected values.
    attr_reader :values

    # @!visibility private
    def initialize(data, bot)
      super

      resolved_users = data.dig('data', 'resolved', 'users') || {}
      @values = data['data']['values'].map { |e| bot.ensure_user(resolved_users[e]) }
    end
  end

  # Event handler for a select user component.

  # Event handler for a select user component.
  class UserSelectEventHandler < ComponentEventHandler
  end

  # Event for when a user interacts with a select role component.

  # Event for when a user interacts with a select role component.
  class RoleSelectEvent < ComponentEvent
    # @return [Array<Role>] Selected values.
    attr_reader :values

    # @!visibility private
    def initialize(data, bot)
      super

      resolved_roles = data.dig('data', 'resolved', 'roles') || {}
      server = bot.server(data['guild_id'])
      @values = data['data']['values'].map { |e| server.role(e.to_i) }
    end
  end

  # Event handler for a select role component.

  # Event handler for a select role component.
  class RoleSelectEventHandler < ComponentEventHandler
  end

  # Event for when a user interacts with a select mentionable component.

  # Event for when a user interacts with a select mentionable component.
  class MentionableSelectEvent < ComponentEvent
    # @return [Hash<Symbol => Array<User>, Symbol => Array<Role>>] Selected values.
    attr_reader :values

    # @!visibility private
    def initialize(data, bot)
      super

      resolved = data.dig('data', 'resolved') || {}
      users = (resolved['users'] || {}).map { |_, user| @bot.ensure_user(user) }
      roles = (resolved['roles'] || {}).map { |_, role| OnyxCord::Role.new(role, @bot) }
      @values = { users: users, roles: roles }
    end
  end

  # Event handler for a select mentionable component.

  # Event handler for a select mentionable component.
  class MentionableSelectEventHandler < ComponentEventHandler
  end

  # Event for when a user interacts with a select channel component.

  # Event for when a user interacts with a select channel component.
  class ChannelSelectEvent < ComponentEvent
    # @return [Array<Channel>] Selected values.
    attr_reader :values

    # @!visibility private
    def initialize(data, bot)
      super

      resolved_channels = data.dig('data', 'resolved', 'channels') || {}
      @values = data['data']['values'].map { |e| bot.ensure_channel(resolved_channels[e]) }
    end
  end

  # Event handler for a select channel component.

  # Event handler for a select channel component.
  class ChannelSelectEventHandler < ComponentEventHandler
  end

  # Event handler for an autocomplete option choices.
end
