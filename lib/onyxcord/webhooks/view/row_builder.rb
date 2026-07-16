# frozen_string_literal: true

class OnyxCord::Webhooks::View
  class RowBuilder
    MAX_BUTTONS_PER_ROW = 5
    MAX_CUSTOM_ID_LENGTH = 100
    MAX_URL_LENGTH = 512
    MAX_LABEL_LENGTH = 80

    # @!visibility private
    def initialize(id: nil)
      @id = id
      @components = []

      yield self if block_given?
    end

    # Add a button to this action row.
    #
    # @param style [Symbol, Integer] The button's style type. See {BUTTON_STYLES}
    # @param id [Integer, nil] The unique 32-bit ID of the button component.
    # @param label [String, nil] The text label.  Either a label or emoji must
    #   be provided (except for premium buttons).
    # @param emoji [#to_h, String, Integer] An emoji to attach.
    # @param custom_id [String] Custom ID for interaction handling.  Required
    #   for styles 1-4 (primary/secondary/success/danger).  Must not exceed
    #   100 characters.
    # @param disabled [true, false, nil] Whether this button is greyed out.
    # @param url [String, nil] The URL for link-style buttons.
    # @param sku_id [String, Integer, nil] SKU ID for premium buttons.
    def button(style:, id: nil, label: nil, emoji: nil, custom_id: nil, disabled: nil, url: nil, sku_id: nil)
      style = BUTTON_STYLES[style] || style

      validate_button!(style, label, emoji, custom_id, url, sku_id)
      validate_row_insertion!(:button)

      emoji = normalize_emoji(emoji)

      @components << {
        type: COMPONENT_TYPES[:button],
        id: id,
        label: label,
        emoji: emoji,
        style: style,
        custom_id: custom_id,
        disabled: disabled,
        url: url,
        sku_id: sku_id
      }.compact
    end

    # Add a string select to this action row.
    #
    # @param custom_id [String] Custom ID.  Limit of 100 characters.
    # @param id [Integer, nil] The unique 32-bit ID.
    # @param options [Array<Hash>] Options that can be selected.
    # @param placeholder [String, nil] Default text when no entries selected.
    # @param min_values [Integer, nil] Minimum selections.
    # @param max_values [Integer, nil] Maximum selections.
    # @param disabled [true, false, nil] Grey out the component.
    # @yieldparam builder [SelectMenuBuilder]
    def string_select(custom_id:, options: [], id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil)
      validate_select_params!(custom_id, placeholder, min_values, max_values)
      validate_row_insertion!(:select)

      builder = SelectMenuBuilder.new(custom_id, options, placeholder, min_values, max_values, disabled, select_type: :string_select, id: id)
      yield builder if block_given?
      @components << builder.to_h
    end

    alias_method :select_menu, :string_select

    # Add a user select to this action row.
    def user_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, default_values: nil)
      validate_select_params!(custom_id, placeholder, min_values, max_values)
      @components << SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :user_select, id: id, default_values: default_values).to_h
    end

    # Add a role select to this action row.
    def role_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, default_values: nil)
      validate_select_params!(custom_id, placeholder, min_values, max_values)
      @components << SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :role_select, id: id, default_values: default_values).to_h
    end

    # Add a mentionable select to this action row.
    def mentionable_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, default_values: nil)
      validate_select_params!(custom_id, placeholder, min_values, max_values)
      @components << SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :mentionable_select, id: id, default_values: default_values).to_h
    end

    # Add a channel select to this action row.
    def channel_select(custom_id:, id: nil, placeholder: nil, min_values: nil, max_values: nil, disabled: nil, types: nil, default_values: nil)
      validate_select_params!(custom_id, placeholder, min_values, max_values)

      builder = SelectMenuBuilder.new(custom_id, [], placeholder, min_values, max_values, disabled, select_type: :channel_select, id: id, default_values: default_values).to_h
      builder[:channel_types] = types.map { |type| OnyxCord::Channel::TYPES[type] || type } if types
      @components << builder
    end

    # @!visibility private
    def to_h
      { type: COMPONENT_TYPES[:action_row], id: @id, components: @components }.compact
    end

    private

    # Validate button constraints (WEBHOOK-0303).
    def validate_button!(style, label, emoji, custom_id, url, sku_id)
      # Link buttons (style 5): must have url, must not have custom_id/sku_id
      if style == BUTTON_STYLES[:link] || style == 5
        raise ArgumentError, 'Link buttons must have a url' if url.nil? || url.to_s.empty?
        raise ArgumentError, 'Link buttons must not have a custom_id' unless custom_id.nil?
        raise ArgumentError, 'Link buttons must not have a sku_id' unless sku_id.nil?
        return
      end

      # Premium buttons (style 6): must have sku_id, must not have label/emoji/url/custom_id
      if style == BUTTON_STYLES[:premium] || style == 6
        raise ArgumentError, 'Premium buttons must have a sku_id' if sku_id.nil?
        raise ArgumentError, 'Premium buttons must not have a label' unless label.nil?
        raise ArgumentError, 'Premium buttons must not have an emoji' unless emoji.nil?
        raise ArgumentError, 'Premium buttons must not have a url' unless url.nil?
        raise ArgumentError, 'Premium buttons must not have a custom_id' unless custom_id.nil?
        return
      end

      # Styles 1-4: must have custom_id
      raise ArgumentError, "Button style #{style} requires a custom_id" if custom_id.nil?

      if custom_id.to_s.length > MAX_CUSTOM_ID_LENGTH
        raise ArgumentError, "custom_id too long: #{custom_id.to_s.length} chars (max #{MAX_CUSTOM_ID_LENGTH})"
      end

      # At least label or emoji is required
      has_label = label.is_a?(String) && !label.empty?
      has_emoji = !emoji.nil?
      raise ArgumentError, 'Buttons must have a label or emoji' unless has_label || has_emoji

      if label.is_a?(String) && label.length > MAX_LABEL_LENGTH
        raise ArgumentError, "Label too long: #{label.length} chars (max #{MAX_LABEL_LENGTH})"
      end

      if url && url.to_s.length > MAX_URL_LENGTH
        raise ArgumentError, "URL too long: #{url.to_s.length} chars (max #{MAX_URL_LENGTH})"
      end
    end

    # Validate select menu common parameters.
    def validate_select_params!(custom_id, placeholder, min_values, max_values)
      raise ArgumentError, 'custom_id is required' if custom_id.nil? || custom_id.to_s.empty?
      if custom_id.to_s.length > 100
        raise ArgumentError, "custom_id too long: #{custom_id.to_s.length} chars (max 100)"
      end
      if placeholder.is_a?(String) && placeholder.length > 150
        raise ArgumentError, "Placeholder too long: #{placeholder.length} chars (max 150)"
      end
      if min_values && max_values && min_values > max_values
        raise ArgumentError, "min_values (#{min_values}) must be <= max_values (#{max_values})"
      end
    end

    # Validate action row constraints (WEBHOOK-0305).
    def validate_row!
      return if @components.empty?

      has_select = @components.any? { |c| c[:type] && [3, 5, 6, 7, 8].include?(c[:type]) }
      has_button = @components.any? { |c| c[:type] == COMPONENT_TYPES[:button] }

      if has_select && has_button
        raise ArgumentError, 'Action rows cannot mix buttons and select menus'
      end

      if has_select && @components.length > 1
        raise ArgumentError, 'Action rows with a select menu must contain exactly one component'
      end

      if has_button && @components.length > MAX_BUTTONS_PER_ROW
        raise ArgumentError, "Action rows can have at most #{MAX_BUTTONS_PER_ROW} buttons"
      end
    end

    # Validate that a new component can be added to the row.
    def validate_row_insertion!(component_type)
      if component_type == :button
        button_count = @components.count { |c| c[:type] == COMPONENT_TYPES[:button] }
        if button_count >= MAX_BUTTONS_PER_ROW
          raise ArgumentError, "Action rows can have at most #{MAX_BUTTONS_PER_ROW} buttons"
        end
      end

      if component_type == :select
        has_button = @components.any? { |c| c[:type] == COMPONENT_TYPES[:button] }
        if has_button
          raise ArgumentError, 'Action rows cannot mix buttons and select menus'
        end
        has_select = @components.any? { |c| c[:type] && [3, 5, 6, 7, 8].include?(c[:type]) }
        if has_select
          raise ArgumentError, 'Action rows with a select menu must contain exactly one component'
        end
      end
    end

    # Normalize an emoji value to a Hash.
    def normalize_emoji(emoji)
      case emoji
      when Integer
        { id: emoji.to_s }
      when String
        emoji.match?(/\A\d+\z/) ? { id: emoji } : { name: emoji }
      when Hash
        emoji
      else
        emoji&.to_h
      end
    end
  end
end
