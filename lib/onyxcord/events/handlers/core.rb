# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # Removes an event handler from this container. If you're looking for a way to do temporary events, I recommend
    # {Await}s instead of this.
    # @param handler [OnyxCord::Events::EventHandler] The handler to remove.
    def remove_handler(handler)
      if handler.is_a?(OnyxCord::Events::RawDispatchHandler)
        @raw_handlers&.delete(handler)
        return
      end

      clazz = EventContainer.event_class(handler.class)
      @event_handlers ||= {}
      @event_handlers[clazz].delete(handler)
    end

    # Remove an application command handler
    # @param name [String, Symbol] The name of the command handler to remove.

    # Remove an application command handler
    # @param name [String, Symbol] The name of the command handler to remove.
    def remove_application_command_handler(name)
      @application_commands.delete(name)
    end

    # Removes all events from this event handler.

    # Removes all events from this event handler.
    def clear!
      @event_handlers&.clear
      @raw_handlers&.clear
      @application_commands&.clear
    end

    # Adds an event handler to this container. Usually, it's more expressive to just use one of the shorthand adder
    # methods like {#message}, but if you want to create one manually you can use this.
    # @param handler [OnyxCord::Events::EventHandler] The handler to add.

    # Adds an event handler to this container. Usually, it's more expressive to just use one of the shorthand adder
    # methods like {#message}, but if you want to create one manually you can use this.
    # @param handler [OnyxCord::Events::EventHandler] The handler to add.
    def add_handler(handler)
      clazz = EventContainer.event_class(handler.class)
      @event_handlers ||= {}
      @event_handlers[clazz] ||= []
      @event_handlers[clazz] << handler
    end

    # Adds all event handlers from another container into this one. Existing event handlers will be overwritten.
    # @param container [Module] A module that `extend`s {EventContainer} from which the handlers will be added.

    # Adds all event handlers from another container into this one. Existing event handlers will be overwritten.
    # @param container [Module] A module that `extend`s {EventContainer} from which the handlers will be added.
    def include_events(container)
      application_command_handlers = container.instance_variable_get(:@application_commands)
      handlers = container.instance_variable_get :@event_handlers
      raw_handlers = container.instance_variable_get(:@raw_handlers)
      return unless handlers || application_command_handlers || raw_handlers

      @event_handlers ||= {}
      @event_handlers.merge!(handlers || {}) { |_, old, new| old + new }

      @raw_handlers ||= []
      @raw_handlers.concat(raw_handlers || [])

      @application_commands ||= {}

      @application_commands.merge!(application_command_handlers || {}) do |_, old, new|
        old.subcommands.merge!(new.subcommands)
        old
      end
    end

    alias_method :include!, :include_events
    alias_method :<<, :add_handler

    # Returns the handler class for an event class type
    # @see #event_class
    # @param event_class [Class] The event type
    # @return [Class] the handler type

    # Returns the handler class for an event class type
    # @see #event_class
    # @param event_class [Class] The event type
    # @return [Class] the handler type
    def self.handler_class(event_class)
      class_from_string("#{event_class}Handler")
    end

    # Returns the event class for a handler class type
    # @see #handler_class
    # @param handler_class [Class] The handler type
    # @return [Class, nil] the event type, or nil if the handler_class isn't a handler class (i.e. ends with Handler)

    # Returns the event class for a handler class type
    # @see #handler_class
    # @param handler_class [Class] The handler type
    # @return [Class, nil] the event type, or nil if the handler_class isn't a handler class (i.e. ends with Handler)
    def self.event_class(handler_class)
      class_name = handler_class.to_s
      return nil unless class_name.end_with? 'Handler'

      EventContainer.class_from_string(class_name[0..-8])
    end

    # Utility method to return a class object from a string of its name. Mostly useful for internal stuff
    # @param str [String] The name of the class
    # @return [Class] the class

    # Utility method to return a class object from a string of its name. Mostly useful for internal stuff
    # @param str [String] The name of the class
    # @return [Class] the class
    def self.class_from_string(str)
      str.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end

    private

    include OnyxCord::Events

    # @return [EventHandler]

    # @return [EventHandler]
    def register_event(clazz, attributes, block)
      handler = EventContainer.handler_class(clazz).new(attributes, block)

      @event_handlers ||= {}
      @event_handlers[clazz] ||= []
      @event_handlers[clazz] << handler

      # Return the handler so it can be removed later
      handler
    end

    def register_raw_handler(filter, block)
      handler = OnyxCord::Events::RawDispatchHandler.new(filter, block)
      @raw_handlers ||= []
      @raw_handlers << handler
      handler
    end
  end
end
