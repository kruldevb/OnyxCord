# frozen_string_literal: true

require 'onyxcord/utils/id_object'

module OnyxCord
  module Interactions
    # Supplemental metadata about an interaction.
    class Metadata
      include IDObject

      attr_reader :type, :user, :target_user, :target_message_id,
                  :triggering_metadata, :interacted_message_id,
                  :original_response_message_id

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

        # INT-0303: sentinel para buscas negativas — permite memorizar "não encontrado"
        @target_message_cache = NOT_FOUND
        @interacted_message_cache = NOT_FOUND
        @original_response_message_cache = NOT_FOUND
      end

      # INT-0303: sentinel marker
      NOT_FOUND = Object.new.freeze

      def user_integration?
        @integration_owners[1] == @user.id
      end

      # INT-0302: server_integration? usa cache do @message.server se disponível
      def server_integration?
        sv = @message.respond_to?(:server) ? @message.server : nil
        sv_id = sv&.id || (@message.respond_to?(:server_id) ? @message.server_id : nil)
        return false unless sv_id
        @integration_owners[0] == sv_id
      end

      # INT-0303: target_message — memoriza nil, não repite REST
      def target_message
        return @target_message_cache unless @target_message_cache.equal?(NOT_FOUND)
        return @target_message_cache = nil unless @target_message_id

        @target_message_cache = fetch_message(@target_message_id)
      end

      # INT-0303: interacted_message — memoriza nil
      def interacted_message
        return @interacted_message_cache unless @interacted_message_cache.equal?(NOT_FOUND)
        return @interacted_message_cache = nil unless @interacted_message_id

        @interacted_message_cache = fetch_message(@interacted_message_id)
      end

      # INT-0303: original_response_message — memoriza nil
      def original_response_message
        return @original_response_message_cache unless @original_response_message_cache.equal?(NOT_FOUND)
        return @original_response_message_cache = nil unless @original_response_message_id

        @original_response_message_cache = fetch_message(@original_response_message_id)
      end

      def command?
        @type == 1
      end

      def component?
        @type == 3
      end

      def modal_submit?
        @type == 5
      end

      # INT-0306: inspect redigido — IDs e tipos, sem PII
      def inspect
        "<Interactions::Metadata id=#{@id} type=#{@type} " \
          "user_id=#{@user&.id.inspect} target_user_id=#{@target_user&.id.inspect} " \
          "target_message_id=#{@target_message_id.inspect} " \
          "interacted_message_id=#{@interacted_message_id.inspect} " \
          "original_response_message_id=#{@original_response_message_id.inspect}>"
      end

      private

      # INT-0303: helper centralizado — usa channel do message sem REST extra se possível
      def fetch_message(msg_id)
        ch = @message.respond_to?(:channel) ? @message.channel : nil
        return nil unless ch

        ch.message(msg_id)
      rescue StandardError
        nil
      end
    end
  end
end