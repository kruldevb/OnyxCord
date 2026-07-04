# frozen_string_literal: true

module OnyxCord
  module EventContainer
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
    def poll_vote_add(attributes = {}, &block)
      register_event(PollVoteAddEvent, attributes, block)
    end

    # This **event** is raised whenever a user removes their vote on a poll.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User, Member] :user A user to match against.
    # @option attributes [String, Integer, Channel] :channel A channel to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Message] :message A message to match against.
    # @option attributes [String, Integer, Answer] :answer A poll answer to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PollVoteRemoveEvent] The event that was raised.
    # @return [PollVoteRemoveEventHandler] The event handler that was registered.

    # This **event** is raised whenever a user removes their vote on a poll.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User, Member] :user A user to match against.
    # @option attributes [String, Integer, Channel] :channel A channel to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Message] :message A message to match against.
    # @option attributes [String, Integer, Answer] :answer A poll answer to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PollVoteRemoveEvent] The event that was raised.
    # @return [PollVoteRemoveEventHandler] The event handler that was registered.
    def poll_vote_remove(attributes = {}, &block)
      register_event(PollVoteRemoveEvent, attributes, block)
    end

    # This **event** is raised when a scheduled event is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :id Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :creator Matches the scheduled event's creator.
    # @option attributes [String, Integer, Channel] :channel Matches the scheduled event's channel.
    # @option attributes [Integer, Symbol, String] :status Matches the status of the scheduled event.
    # @option attributes [Integer, String] :entity_id Matches the entity ID of the scheduled event.
    # @option attributes [Integer, Symbol, String] :entity_type Matches the entity type of the scheduled event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventCreateEvent] The event that was raised.
    # @return [ScheduledEventCreateEventHandler] the event handler that was registered.

    # This **event** is raised when a scheduled event is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :id Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :creator Matches the scheduled event's creator.
    # @option attributes [String, Integer, Channel] :channel Matches the scheduled event's channel.
    # @option attributes [Integer, Symbol, String] :status Matches the status of the scheduled event.
    # @option attributes [Integer, String] :entity_id Matches the entity ID of the scheduled event.
    # @option attributes [Integer, Symbol, String] :entity_type Matches the entity type of the scheduled event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventCreateEvent] The event that was raised.
    # @return [ScheduledEventCreateEventHandler] the event handler that was registered.
    def scheduled_event_create(attributes = {}, &block)
      register_event(ScheduledEventCreateEvent, attributes, block)
    end

    # This **event** is raised when a scheduled event is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :id Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :creator Matches the scheduled event's creator.
    # @option attributes [String, Integer, Channel] :channel Matches the scheduled event's channel.
    # @option attributes [Integer, Symbol, String] :status Matches the status of the scheduled event.
    # @option attributes [Integer, String] :entity_id Matches the entity ID of the scheduled event.
    # @option attributes [Integer, Symbol, String] :entity_type Matches the entity type of the scheduled event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventUpdateEvent] The event that was raised.
    # @return [ScheduledEventUpdateEventHandler] the event handler that was registered.

    # This **event** is raised when a scheduled event is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :id Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :creator Matches the scheduled event's creator.
    # @option attributes [String, Integer, Channel] :channel Matches the scheduled event's channel.
    # @option attributes [Integer, Symbol, String] :status Matches the status of the scheduled event.
    # @option attributes [Integer, String] :entity_id Matches the entity ID of the scheduled event.
    # @option attributes [Integer, Symbol, String] :entity_type Matches the entity type of the scheduled event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventUpdateEvent] The event that was raised.
    # @return [ScheduledEventUpdateEventHandler] the event handler that was registered.
    def scheduled_event_update(attributes = {}, &block)
      register_event(ScheduledEventUpdateEvent, attributes, block)
    end

    # This **event** is raised when a scheduled event is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :id Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :creator Matches the scheduled event's creator.
    # @option attributes [String, Integer, Channel] :channel Matches the scheduled event's channel.
    # @option attributes [Integer, Symbol, String] :status Matches the status of the scheduled event.
    # @option attributes [Integer, String] :entity_id Matches the entity ID of the scheduled event.
    # @option attributes [Integer, Symbol, String] :entity_type Matches the entity type of the scheduled event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventDeleteEvent] The event that was raised.
    # @return [ScheduledEventDeleteEventHandler] the event handler that was registered.

    # This **event** is raised when a scheduled event is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :id Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :creator Matches the scheduled event's creator.
    # @option attributes [String, Integer, Channel] :channel Matches the scheduled event's channel.
    # @option attributes [Integer, Symbol, String] :status Matches the status of the scheduled event.
    # @option attributes [Integer, String] :entity_id Matches the entity ID of the scheduled event.
    # @option attributes [Integer, Symbol, String] :entity_type Matches the entity type of the scheduled event.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventDeleteEvent] The event that was raised.
    # @return [ScheduledEventDeleteEventHandler] the event handler that was registered.
    def scheduled_event_delete(attributes = {}, &block)
      register_event(ScheduledEventDeleteEvent, attributes, block)
    end

    # This **event** is raised when a user is added to a scheduled event.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :scheduled_event Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :user Matches the user that was added.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventUserAddEvent] The event that was raised.
    # @return [ScheduledEventUserAddEventHandler] the event handler that was registered.

    # This **event** is raised when a user is added to a scheduled event.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :scheduled_event Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :user Matches the user that was added.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventUserAddEvent] The event that was raised.
    # @return [ScheduledEventUserAddEventHandler] the event handler that was registered.
    def scheduled_event_user_add(attributes = {}, &block)
      register_event(ScheduledEventUserAddEvent, attributes, block)
    end

    # This **event** is raised when a user is removed from a scheduled event.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :scheduled_event Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :user Matches the user that was removed.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventUserRemoveEvent] The event that was raised.
    # @return [ScheduledEventUserRemoveEventHandler] the event handler that was registered.

    # This **event** is raised when a user is removed from a scheduled event.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the scheduled event's server.
    # @option attributes [String, Integer, ScheduledEvent] :scheduled_event Matches the scheduled event.
    # @option attributes [String, Integer, User, Member] :user Matches the user that was removed.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ScheduledEventUserRemoveEvent] The event that was raised.
    # @return [ScheduledEventUserRemoveEventHandler] the event handler that was registered.
    def scheduled_event_user_remove(attributes = {}, &block)
      register_event(ScheduledEventUserRemoveEvent, attributes, block)
    end

    # This **event** is raised whenever an integration is added to a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Integration] :id An integration to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Application] :application An application to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [IntegrationCreateEvent] The event that was raised.
    # @return [IntegrationCreateEventHandler] The event handler that was registered.

    # This **event** is raised whenever an integration is added to a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Integration] :id An integration to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Application] :application An application to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [IntegrationCreateEvent] The event that was raised.
    # @return [IntegrationCreateEventHandler] The event handler that was registered.
    def integration_create(attributes = {}, &block)
      register_event(IntegrationCreateEvent, attributes, block)
    end

    # This **event** is raised whenever an integration is updated in a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Integration] :id An integration to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Application] :application An application to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [IntegrationUpdateEvent] The event that was raised.
    # @return [IntegrationUpdateEventHandler] The event handler that was registered.

    # This **event** is raised whenever an integration is updated in a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Integration] :id An integration to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Application] :application An application to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [IntegrationUpdateEvent] The event that was raised.
    # @return [IntegrationUpdateEventHandler] The event handler that was registered.
    def integration_update(attributes = {}, &block)
      register_event(IntegrationUpdateEvent, attributes, block)
    end

    # This **event** is raised whenever an integration is removed from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Integration] :id An integration to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Application] :application An application to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [IntegrationDeleteEvent] The event that was raised.
    # @return [IntegrationDeleteEventHandler] The event handler that was registered.

    # This **event** is raised whenever an integration is removed from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Integration] :id An integration to match against.
    # @option attributes [String, Integer, Server] :server A server to match against.
    # @option attributes [String, Integer, Application] :application An application to match against.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [IntegrationDeleteEvent] The event that was raised.
    # @return [IntegrationDeleteEventHandler] The event handler that was registered.
    def integration_delete(attributes = {}, &block)
      register_event(IntegrationDeleteEvent, attributes, block)
    end

    # This **event** is raised for every dispatch received over the gateway, whether supported by onyxcord or not.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Symbol, Regexp] :type Matches the event type of the dispatch.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [RawEvent] The event that was raised.
    # @return [RawEventHandler] The event handler that was registered.
  end
end
