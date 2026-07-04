# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class SelectMenuBuilder
    # @!visibility private
    def initialize(custom_id, options = [], placeholder = nil, min_values = nil, max_values = nil, disabled = nil, select_type: :string_select, id: nil, required: nil, default_values: nil)
      @id = id
      @custom_id = custom_id
      @options = options
      @placeholder = placeholder
      @min_values = min_values
      @max_values = max_values
      @disabled = disabled
      @select_type = select_type
      @required = required
      @default_values = process_defaults(default_values)
    end

    # Add an option to this select menu.
    # @param label [String] The title of this option.
    # @param value [String] The value that this option represents.
    # @param description [String, nil] An optional description of the option.
    # @param emoji [#to_h, String, Integer] An emoji ID, or unicode emoji to attach to the button. Can also be an object
    #   that responds to `#to_h` which returns a hash in the format of `{ id: Integer, name: string }`.
    # @param default [true, false, nil] Whether this is the default selected option.
    def option(label:, value:, description: nil, emoji: nil, default: nil)
      emoji = case emoji
              when Integer, String
                emoji.to_i.positive? ? { id: emoji } : { name: emoji }
              else
                emoji&.to_h
              end

      @options << { label: label, value: value, description: description, emoji: emoji, default: default }
    end

    # @!visibility private
    def to_h
      {
        type: COMPONENT_TYPES[@select_type],
        id: @id,
        options: @options,
        placeholder: @placeholder,
        min_values: @min_values,
        max_values: @max_values,
        custom_id: @custom_id,
        disabled: @disabled,
        required: @required,
        default_values: @default_values
      }.compact
    end

    private

    # @!visibility private
    def process_defaults(default_values)
      if @select_type == :mentionable_select
        default_values&.map do |default_value|
          case default_value
          when OnyxCord::Recipient, OnyxCord::User, OnyxCord::Member
            { id: default_value.id, type: :user }
          when OnyxCord::Role
            { id: default_value.id, type: :role }
          when Hash
            default_value
          else
            raise TypeError, "Unsupported type: #{default_value.class}"
          end
        end
      else
        default_values&.map { |id| id.is_a?(Hash) ? id : { id: id.resolve_id, type: @select_type[..-8] } }
      end
    end
  end

  # A text display component allows you to send message content.
end
