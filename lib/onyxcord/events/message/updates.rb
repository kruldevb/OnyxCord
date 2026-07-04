# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Raised when a message is edited
  # @see OnyxCord::EventContainer#message_edit
  class MessageEditEvent < MessageEvent; end

  # Event handler for {MessageEditEvent}

  # Event handler for {MessageEditEvent}
  class MessageEditEventHandler < MessageEventHandler; end

  # Raised when a message is deleted
  # @see OnyxCord::EventContainer#message_delete

  # Raised whenever a MESSAGE_UPDATE is received
  # @see OnyxCord::EventContainer#message_update
  class MessageUpdateEvent < MessageEvent; end

  # Event handler for {MessageUpdateEvent}

  # Event handler for {MessageUpdateEvent}
  class MessageUpdateEventHandler < MessageEventHandler; end
end
