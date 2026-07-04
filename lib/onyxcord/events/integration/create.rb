# frozen_string_literal: true

require 'onyxcord/events/integration/base'

module OnyxCord::Events
  # Raised whenever an integration is created.
  class IntegrationCreateEvent < IntegrationEvent; end

  # Event handler for INTEGRATION_CREATE events.
  class IntegrationCreateEventHandler < IntegrationEventHandler; end
end
