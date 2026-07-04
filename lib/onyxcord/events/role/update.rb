# frozen_string_literal: true

require 'onyxcord/events/role/create'

module OnyxCord::Events
  # Event raised when a role updates on a server
  class ServerRoleUpdateEvent < ServerRoleCreateEvent; end

  # Event handler for ServerRoleUpdateEvent
  class ServerRoleUpdateEventHandler < ServerRoleCreateEventHandler; end
end
