# frozen_string_literal: true

require 'onyxcord/utils/id_object'

module OnyxCord
  module Interactions
    # A message partial for interactions.
    class Message
      include IDObject

      attr_reader :interaction, :content, :pinned, :tts, :timestamp,
                  :edited_timestamp, :edited, :id, :author,
                  :attachments, :embeds, :mentions, :flags,
                  :channel_id, :message_reference, :components

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

        @server_id = @interaction.respond_to?(:server_id) ? @interaction.server_id : nil

        @timestamp = Time.parse(data['timestamp']) if data['timestamp']
        @edited_timestamp = data['edited_timestamp'].nil? ? nil : Time.parse(data['edited_timestamp'])
        @edited = !@edited_timestamp.nil?

        @id = data['id'].to_i

        @author = bot.ensure_user(data['author'] || data['member']['user'])

        # INT-0305: conversão lazy — só materializa se acessado
        @attachments_raw = data['attachments']
        @embeds_raw = data['embeds']
        @mentions_raw = data['mentions']
        @components_raw = data['components']

        @mention_roles = data['mention_roles']
        @mention_everyone = data['mention_everyone']
        @flags = data['flags']
        # INT-0305: @pinned já setado acima — remoção do duplo
        @components = nil
      end

      # INT-0305: lazy attachments
      def attachments
        return @attachments if defined?(@attachments)
        @attachments = @attachments_raw ? @attachments_raw.map { |e| Attachment.new(e, self, @bot) } : []
      end

      # INT-0305: lazy embeds
      def embeds
        return @embeds if defined?(@embeds)
        @embeds = @embeds_raw ? @embeds_raw.map { |e| Embed.new(e, self) } : []
      end

      # INT-0305: lazy mentions
      def mentions
        return @mentions if defined?(@mentions)
        @mentions = []
        @mentions_raw&.each { |element| @mentions << @bot.ensure_user(element) }
        @mentions
      end

      # INT-0305: lazy components
      def components
        return @components if defined?(@components)
        @components = @components_raw&.filter_map { |component| Components.from_data(component, @bot) } || []
        @components
      end

      # INT-0302: member usa cache, não REST implícito
      # @return [Member, nil]
      def member
        return @member if defined?(@member)
        return @member = nil unless @server_id && @author
        sv = server
        return @member = nil unless sv
        @member = sv.member(@author.id) rescue nil
      end

      # INT-0302: server consulta cache explicitamente
      # @return [Server, nil]
      def server
        return @server if defined?(@server)
        @server = @server_id ? @bot.server(@server_id) : nil
      end

      # INT-0302: channel reusa interaction.channel se disponível
      # @return [Channel]
      def channel
        return @channel if defined?(@channel)
        # Tentar interaction.channel primeiro (sem REST)
        if @interaction.respond_to?(:channel) && @interaction.channel
          @channel = @interaction.channel
          return @channel
        end
        @channel = @bot.channel(@channel_id)
      end

      def respond(content: nil, embeds: nil, allowed_mentions: nil, flags: 0, ephemeral: true, components: nil, attachments: nil, &block)
        @interaction.send_message(content: content, embeds: embeds, allowed_mentions: allowed_mentions, flags: flags, ephemeral: ephemeral, components: components, attachments: attachments, &block)
      end

      def delete
        @interaction.delete_message(@id)
      end

      def edit(content: nil, embeds: nil, allowed_mentions: nil, components: nil, attachments: nil, &block)
        @interaction.edit_message(@id, content: content, embeds: embeds, allowed_mentions: allowed_mentions, components: components, attachments: attachments, &block)
      end

      # @return [OnyxCord::Message]
      def to_message
        OnyxCord::Message.new(@data, @bot)
      end

      alias_method :message, :to_message

      # INT-0306: inspect redigido — IDs e contagens, sem PII
      def inspect
        content_preview = @content&.slice(0, 50)
        "<Interaction::Message id=#{@id} channel_id=#{@channel_id} server_id=#{@server_id.inspect} " \
          "author_id=#{@author&.id.inspect} flags=#{@flags.inspect} " \
          "content=#{content_preview.inspect} (#{(@content || '').length} chars) " \
          "embeds=#{(@embeds_raw || []).size} attachments=#{(@attachments_raw || []).size} " \
          "mentions=#{(@mentions_raw || []).size} components=#{(@components_raw || []).size}>"
      end
    end
  end
end
