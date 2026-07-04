# frozen_string_literal: true

module OnyxCord
  # Helpers for Discord message component payloads.
  module MessageComponents
    # Discord message flag for the Components V2 layout system.
    IS_COMPONENTS_V2 = 1 << 15

    # Component types that only exist in the Components V2 message system.
    V2_COMPONENT_TYPES = [9, 10, 11, 12, 13, 14, 17].freeze

    module_function

    def payload(components)
      case components
      when nil
        []
      when Array
        components.map { |component| component.respond_to?(:to_h) ? component.to_h : component }
      when Hash
        [components]
      else
        if components.respond_to?(:to_a)
          components.to_a
        elsif components.respond_to?(:to_h)
          [components.to_h]
        else
          Array(components)
        end
      end
    end

    def components_v2?(components)
      payload(components).any? { |component| component_v2?(component) }
    end

    def apply_v2_flag(flags, components, force: false)
      return flags unless force || components_v2?(components)

      flag_value(flags) | IS_COMPONENTS_V2
    end

    def component_v2?(component)
      return false if component.nil?

      component = component.to_h if component.respond_to?(:to_h)
      return false unless component.is_a?(Hash)

      type = component[:type] || component['type']
      return true if V2_COMPONENT_TYPES.include?(type)

      children = component[:components] || component['components']
      return true if children && components_v2?(children)

      accessory = component[:accessory] || component['accessory']
      component_v2?(accessory)
    end

    def flag_value(flags)
      case flags
      when nil, :undef
        0
      when Array
        flags.map { |flag| flag.respond_to?(:to_i) ? flag.to_i : 0 }.reduce(0, &:|)
      else
        flags.respond_to?(:to_i) ? flags.to_i : 0
      end
    end
  end
end
