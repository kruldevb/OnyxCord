# frozen_string_literal: true

require 'onyxcord/events/integration/base'

module OnyxCord::Events
  # Raised whenever an integration is updated.
  class IntegrationUpdateEvent < IntegrationEvent; end

  # Event handler for INTEGRATION_UPDATE events.
  class IntegrationUpdateEventHandler < IntegrationEventHandler; end
end
