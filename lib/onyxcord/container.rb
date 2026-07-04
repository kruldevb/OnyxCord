# frozen_string_literal: true

require 'onyxcord/events/message'
require 'onyxcord/events/typing'
require 'onyxcord/events/lifetime'
require 'onyxcord/events/presence'
require 'onyxcord/events/voice_state_update'
require 'onyxcord/events/voice_server_update'
require 'onyxcord/events/channels'
require 'onyxcord/events/members'
require 'onyxcord/events/roles'
require 'onyxcord/events/guilds'
require 'onyxcord/events/await'
require 'onyxcord/events/bans'
require 'onyxcord/events/raw'
require 'onyxcord/events/reactions'
require 'onyxcord/events/invites'
require 'onyxcord/events/interactions'
require 'onyxcord/events/integrations'
require 'onyxcord/events/scheduled_events'
require 'onyxcord/events/polls'
require 'onyxcord/events/threads'
require 'onyxcord/events/webhooks'

require 'onyxcord/await'

module OnyxCord
  # This module provides the functionality required for events and awaits. It is separated
  # from the {Bot} class so users can make their own container modules and include them.
  module EventContainer
  end
end

require 'onyxcord/events/handlers/messages'
require 'onyxcord/events/handlers/lifetime'
require 'onyxcord/events/handlers/reactions'
require 'onyxcord/events/handlers/presence'
require 'onyxcord/events/handlers/channels'
require 'onyxcord/events/handlers/voice'
require 'onyxcord/events/handlers/guilds'
require 'onyxcord/events/handlers/interactions'
require 'onyxcord/events/handlers/scheduled_events'
require 'onyxcord/events/handlers/raw'
require 'onyxcord/events/handlers/core'
