# frozen_string_literal: true

require 'onyxcord/events/generic'
require 'onyxcord/models'

module OnyxCord::Events
  # Event handler for an autocomplete option choices.
  class AutocompleteEventHandler < InteractionCreateEventHandler
    def matches?(event)
      return false unless super
      return false unless event.is_a?(AutocompleteEvent)

      [
        matches_all(@attributes[:name], event.focused) { |a, e| a == e },
        matches_all(@attributes[:command_id], event.command_id) { |a, e| a&.to_i == e },
        matches_all(@attributes[:subcommand], event.subcommand) { |a, e| a&.to_sym == e },
        matches_all(@attributes[:command_name], event.command_name) { |a, e| a&.to_sym == e },
        matches_all(@attributes[:subcommand_group], event.subcommand_group) { |a, e| a&.to_sym == e },
        matches_all(@attributes[:server], event.server_id) { |a, e| a&.resolve_id == e }
      ].reduce(&:&)
    end
  end

  # An event for an autocomplete option choice.

  # An event for an autocomplete option choice.
  class AutocompleteEvent < ApplicationCommandEvent
    # @return [String] Name of the currently focused option.
    attr_reader :focused

    # @return [Hash] An empty hash that can be used to return choices by adding K/V pairs.
    attr_reader :choices

    # @!visibility private
    def initialize(data, bot)
      super

      @choices = {}

      options = data['data']['options']

      options = case options[0]['type']
                when 1
                  options[0]['options']
                when 2
                  options[0]['options'][0]['options']
                else
                  options
                end

      @focused = options.find { |opt| opt.key?('focused') }['name']
    end

    # Respond to this interaction with autocomplete choices.
    # @param choices [Array<Hash>, Hash, nil] Autocomplete choices to return.
    def respond(choices:)
      @interaction.show_autocomplete_choices(choices || [])
    end
  end

  # An event for whenever an application command's permissions are updated.
end
