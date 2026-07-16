# frozen_string_literal: true

require 'onyxcord/core/bootstrap'
require 'onyxcord/utils/id_object'
require 'onyxcord/utils/permissions'
require 'onyxcord/rest/client'
require 'onyxcord/rest/routes/user'

require 'onyxcord/light/credential'
require 'onyxcord/light/light_bot'

# This module contains classes to allow connections to bots without a connection to the gateway socket, i.e. bots
# that only use the REST part of the API.
module OnyxCord::Light
end
