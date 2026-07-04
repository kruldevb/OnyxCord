# frozen_string_literal: true

require 'onyxcord/utils/id_object'

module OnyxCord
  module Interactions
    # A message partial for interactions.
    class Message
      include IDObject

      # @return [Interaction] The interaction that created this message.
      attr_reader :interaction

      # @return [String, nil] The content of the message.
      attr_reader :content

      # @return [true, false] Whether this message is pinned in the channel it belongs to.
      attr_reader :pinned

      # @return [true, false]
      attr_reader :tts

      # @return [Time]
      attr_reader :timestamp

      # @return [Time, nil]
      attr_reader :edited_timestamp

      # @return [true, false]
      attr_reader :edited

      # @return [Integer]
      attr_reader :id

      # @return [User] The user of the application.
      attr_reader :author

      # @return [Attachment]
      attr_reader :attachments

      # @return [Array<Embed>]
      attr_reader :embeds

      # @return [Array<User>]
      attr_reader :mentions

      # @return [Integer]
      attr_reader :flags

      # @return [Integer]
      attr_reader :channel_id

      # @return [Hash, nil]
      attr_reader :message_reference

      # @return [Array<Component>]
      attr_reader :components

      # @!visibility private
      def initialize(data, bot, interaction)
        @data = data
        @bot = bot
        @interaction = interaction
        @content = data['content']
        @channel_id = data['channel_id'].to_i
        @pinned = data['pinned']
        @tts = data['tts']

        @message_reference = data['message_reference']

        @server_id = @interaction.server_id

        @timestamp = Time.parse(data['timestamp']) if data['timestamp']
        @edited_timestamp = data['edited_timestamp'].nil? ? nil : Time.parse(data['edited_timestamp'])
        @edited = !@edited_timestamp.nil?

        @id = data['id'].to_i

        @author = bot.ensure_user(data['author'] || data['member']['user'])

        @attachments = []
        @attachments = data['attachments'].map { |e| Attachment.new(e, self, @bot) } if data['attachments']

        @embeds = []
        @embeds = data['embeds'].map { |e| Embed.new(e, self) } if data['embeds']

        @mentions = []

        data['mentions']&.each do |element|
          @mentions << bot.ensure_user(element)
        end

        @mention_roles = data['mention_roles']
        @mention_everyone = data['mention_everyone']
        @flags = data['flags']
        @pinned = data['pinned']
        @components = data['components']&.filter_map { |component| Components.from_data(component, @bot) } || []
      end

      # @return [Member, nil] This will return nil if the bot does not have access to the
      #   server the interaction originated in.
      def member
        server&.member(@user.id)
      end

      # @return [Server, nil] This will return nil if the bot does not have access to the
      #   server the interaction originated in.
      def server
        @bot.server(@server_id)
      end

      # @return [Channel] The channel the interaction originates from.
      # @raise [Errors::NoPermission] When the bot is not in the server associated with this interaction.
      def channel
        @bot.channel(@channel_id)
      end

      # Respond to this message.
      # @param (see Interaction#send_message)
      # @yieldparam (see Interaction#send_message)
      def respond(content: nil, embeds: nil, allowed_mentions: nil, flags: 0, ephemeral: true, components: nil, attachments: nil, &block)
        @interaction.send_message(content: content, embeds: embeds, allowed_mentions: allowed_mentions, flags: flags, ephemeral: ephemeral, components: components, attachments: attachments, &block)
      end

      # Delete this message.
      def delete
        @interaction.delete_message(@id)
      end

      # Edit this message's data.
      # @param content (see Interaction#send_message)
      # @param embeds (see Interaction#send_message)
      # @param allowed_mentions (see Interaction#send_message)
      # @yieldparam (see Interaction#send_message)
      def edit(content: nil, embeds: nil, allowed_mentions: nil, components: nil, attachments: nil, &block)
        @interaction.edit_message(@id, content: content, embeds: embeds, allowed_mentions: allowed_mentions, components: components, attachments: attachments, &block)
      end

      # @return [OnyxCord::Message]
      def to_message
        OnyxCord::Message.new(@data, @bot)
      end

      alias_method :message, :to_message

      # @!visibility private
      def inspect
        "<Interaction::Message content=#{@content.inspect} embeds=#{@embeds.inspect} channel_id=#{@channel_id} server_id=#{@server_id} author=#{@author.inspect}>"
      end
    end
  end
end
