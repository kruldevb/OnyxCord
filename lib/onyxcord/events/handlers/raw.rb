# frozen_string_literal: true

module OnyxCord
  module EventContainer
    # This **event** is raised for every dispatch received over the gateway, whether supported by onyxcord or not.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Symbol, Regexp] :type Matches the event type of the dispatch.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [RawEvent] The event that was raised.
    # @return [RawEventHandler] The event handler that was registered.
    def raw(filter = nil, &block)
      filter = filter[:type] || filter[:t] if filter.is_a?(Hash)
      register_raw_handler(filter, block)
    end

    # This **event** is raised for a dispatch received over the gateway that is not currently handled otherwise by
    # onyxcord.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Symbol, Regexp] :type Matches the event type of the dispatch.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UnknownEvent] The event that was raised.
    # @return [UnknownEventHandler] The event handler that was registered.

    # This **event** is raised for a dispatch received over the gateway that is not currently handled otherwise by
    # onyxcord.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Symbol, Regexp] :type Matches the event type of the dispatch.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UnknownEvent] The event that was raised.
    # @return [UnknownEventHandler] The event handler that was registered.
    def unknown(attributes = {}, &block)
      register_event(UnknownEvent, attributes, block)
    end

    # Removes an event handler from this container. If you're looking for a way to do temporary events, I recommend
    # {Await}s instead of this.
    # @param handler [OnyxCord::Events::EventHandler] The handler to remove.
  end
end
