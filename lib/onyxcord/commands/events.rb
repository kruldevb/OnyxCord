# frozen_string_literal: true

require 'onyxcord/events/message'

module OnyxCord::Commands
  # Extension of MessageEvent for commands that contains the command called and makes the bot readable
  class CommandEvent < OnyxCord::Events::MessageEvent
    attr_reader :bot
    attr_accessor :command
  end
end
