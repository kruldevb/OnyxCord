# frozen_string_literal: true

require 'onyxcord/utils/id_object'

module OnyxCord
  module Interactions
    # Supplemental metadata about an interaction.
    class Metadata
      include IDObject

      # @return [Integer] the type of the interaction.
      attr_reader :type

      # @return [User] the user that initiated the interaction.
      attr_reader :user

      # @return [User, nil] the user that the command was ran on.
      attr_reader :target_user

      # @return [Integer, nil] the ID of the message the command was ran on.
      attr_reader :target_message_id

      # @return [Metadata, nil] the metadata for the interaction that opened the modal.
      attr_reader :triggering_metadata

      # @return [Integer, nil] the ID of the message that contained the interactive message component.
      attr_reader :interacted_message_id

      # @return [Integer, nil] the ID the original response message; only present on follow-up messages.
      attr_reader :original_response_message_id

      # @!visibility private
      def initialize(data, message, bot)
        @bot = bot
        @message = message
        @id = data['id'].to_i
        @type = data['type']
        @user = bot.ensure_user(data['user']) if data['user']
        @target_user = bot.ensure_user(data['target_user']) if data['target_user']
        @target_message_id = data['target_message_id']&.to_i
        @triggering_metadata = Metadata.new(data['triggering_interaction_metadata'], @message, @bot) if data['triggering_interaction_metadata']
        @interacted_message_id = data['interacted_message_id']&.to_i
        @original_response_message_id = data['original_response_message_id']&.to_i
        @integration_owners = data['authorizing_integration_owners']&.to_h { |key, value| [key.to_i, value.to_i] }
      end

      # Check if the interaction was triggered by a user by installed the application.
      # @return [true, false] whether or not the application was installed by the user
      #   who initiated this interaction.
      def user_integration?
        @integration_owners[1] == @user.id
      end

      # Check if the interaction was triggered by a server by installed the application.
      # @return [true, false] whether or not the application was installed by the server
      #   where this interaction originates from.
      def server_integration?
        @integration_owners[0] == @message.server.id
      end

      # Attempt to fetch the target message of the interaction.
      # @return [Message, nil] the target message of the interaction, or `nil` if it couldn't be found.
      def target_message
        return unless @target_message_id

        @target_message ||= @message.channel.message(@target_message_id)
      end

      # Attempt to fetch the message that contained the interatctive component.
      # @return [Message, nil] the interacted message with the component, or `nil` if it couldn't be found.
      def interacted_message
        return unless @interacted_message_id

        @interacted_message ||= @message.channel.message(@interacted_message_id)
      end

      # Attempt to fetch the original response message of the interaction.
      # @return [Message, nil] the original response message of the interaction, or `nil` if it couldn't be found.
      def original_response_message
        return unless @original_response_message_id

        @original_response_message ||= @message.channel.message(@original_response_message_id)
      end

      # @!method command?
      #  @return [true, false] whether or not the interaction metadata is for an application command.
      # @!method component?
      #  @return [true, false] whether or not the interaction metadata is for a message component.
      # @!method modal_submit?
      #  @return [true, false] whether or not the interaction metadata is for a modal submission.
      def command?
        @type == 1
      end

      def component?
        @type == 3
      end

      def modal_submit?
        @type == 5
      end

      # @!visibility private
      def inspect
        "<Interactions::Metadata id=#{@id} type=#{@type} user=#{@user.inspect} target_user=#{@target_user.inspect}>"
      end
    end
  end
end
