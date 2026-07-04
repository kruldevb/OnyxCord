# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class RowBuilder
    # @!visibility private
    def initialize(id: nil)
      @id = id
      @components = []

      yield self if block_given?
    end

    # Add a button to this action row.
    # @param style [Symbol, Integer] The button's style type. See {BUTTON_STYLES}
    # @param id [Integer, nil] The unique 32-bit ID of the button component. This is not to be confused with the `custom_id`.
    # @param label [String, nil] The text label for the button. Either a label or emoji must be provided.
    # @param emoji [#to_h, String, Integer] An emoji ID, or unicode emoji to attach to the button. Can also be an object
    #   that responds to `#to_h` which returns a hash in the format of `{ id: Integer, name: string }`.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    #   There is a limit of 100 characters to each custom_id.
    # @param disabled [true, false] Whether this button is disabled and shown as greyed out.
    # @param url [String, nil] The URL, when using a link style button.
    def button(style:, id: nil, label: nil, emoji: nil, custom_id: nil, disabled: nil, url: nil, sku_id: nil)
      style = BUTTON_STYLES[style] || style

      emoji = case emoji
              when Integer, String
                emoji.to_i.positive? ? { id: emoji } : { name: emoji }
              else
                emoji&.to_h
              end

      @components << { type: COMPONENT_TYPES[:button], id: id, label: label, emoji: emoji, style: style, custom_id: custom_id, disabled: disabled, url: url, sku_id: sku_id }.compact
    end

    # Add a string select to this action row.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    #   There is a limit of 100 characters to each custom_id.
    # @param id [Integer, nil] The unique 32-bit ID of the string select. This is not to be confused with the `custom_id`.
    # @param options [Array<Hash>] Options that can be selected in this menu. Can also be provided via the yielded builder.
    # @param placeholder [String, nil] Default text to show when no entries are selected.
    # @param min_values [Integer, nil] The minimum amount of values a user must select.
    # @param max_values [Integer, nil] The maximum amount of values a user can select.
    # @param disabled [true, false, nil] Grey out the component to make it unusable.
    # @yieldparam builder [SelectMenuBuilder]
    def string_select(custom_id:, options: [], id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil)
      builder = SelectMenuBuilder.new(custom_id, options, placeholder, min_values, max_values, disabled, select_type: :string_select, id: id)

      yield builder if block_given?

      @components << builder.to_h
    end

    alias_method :select_menu, :string_select

    # Add a user select to this action row.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    #   There is a limit of 100 characters to each custom_id.
    # @param id [Integer, nil] The unique 32-bit ID of the user select. This is not to be confused with the `custom_id`.
    # @param placeholder [String, nil] Default text to show when no entries are selected.
    # @param min_values [Integer, nil] The minimum amount of values a user must select.
    # @param max_values [Integer, nil] The maximum amount of values a user can select.
    # @param disabled [true, false, nil] Grey out the component to make it unusable.
    # @param default_values [Array<User, Member, Recipient, Integer, String, Hash>, nil] The users to populate in the select menu by default.
    def user_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, default_values: nil)
      @components << SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :user_select, id: id, default_values: default_values).to_h
    end

    # Add a role select to this action row.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    #   There is a limit of 100 characters to each custom_id.
    # @param id [Integer, nil] The unique 32-bit ID of the role select. This is not to be confused with the `custom_id`.
    # @param placeholder [String, nil] Default text to show when no entries are selected.
    # @param min_values [Integer, nil] The minimum amount of values a user must select.
    # @param max_values [Integer, nil] The maximum amount of values a user can select.
    # @param disabled [true, false, nil] Grey out the component to make it unusable.
    # @param default_values [Array<Role, Integer, String, Hash>, nil] The roles to populate in the select menu by default.
    def role_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, default_values: nil)
      @components << SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :role_select, id: id, default_values: default_values).to_h
    end

    # Add a mentionable select to this action row.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    #   There is a limit of 100 characters to each custom_id.
    # @param id [Integer, nil] The unique 32-bit ID of the mentionable select. This is not to be confused with the `custom_id`.
    # @param placeholder [String, nil] Default text to show when no entries are selected.
    # @param min_values [Integer, nil] The minimum amount of values a user must select.
    # @param max_values [Integer, nil] The maximum amount of values a user can select.
    # @param disabled [true, false, nil] Grey out the component to make it unusable.
    # @param default_values [Array<User, Role, Member, Recipient, Hash>, nil] The mentionable entities to populate in the select menu by default.
    def mentionable_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, default_values: nil)
      @components << SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :mentionable_select, id: id, default_values: default_values).to_h
    end

    # Add a channel select to this action row.
    # @param custom_id [String] Custom IDs are used to pass state to the events that are raised from interactions.
    #   There is a limit of 100 characters to each custom_id.
    # @param id [Integer, nil] The unique 32-bit ID of the channel select. This is not to be confused with the `custom_id`.
    # @param placeholder [String, nil] Default text to show when no entries are selected.
    # @param min_values [Integer, nil] The minimum amount of values a user must select.
    # @param max_values [Integer, nil] The maximum amount of values a user can select.
    # @param disabled [true, false, nil] Grey out the component to make it unusable.
    # @param types [Array<Symbol, Integer>, nil] The channel types to include in the select menu.
    # @param default_values [Array<Channel, Integer, String, Hash>, nil] The channels to populate in the select menu by default.
    def channel_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, types: nil, default_values: nil)
      builder = SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :channel_select, id: id, default_values: default_values).to_h

      builder[:channel_types] = types.map { |type| OnyxCord::Channel::TYPES[type] || type } if types

      @components << builder
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:action_row], id: @id, components: @components }.compact
    end
  end

  # A builder to assist in adding options to select menus.
end
