# frozen_string_literal: true

module OnyxCord
  class Bot
    module Messaging
      # A handle for a temporary message that can be cancelled.
      class TemporaryMessage
        attr_reader :message

        def initialize(message, thread)
          @message = message
          @thread = thread
          @cancelled = false
          @mutex = Mutex.new
        end

        # Cancel the pending deletion, keeping the message.
        # @return [true, false] whether cancellation succeeded (false if already deleted or cancelled).
        def cancel
          @mutex.synchronize do
            return false if @cancelled

            @cancelled = true
            @thread&.kill
            true
          end
        end

        # Whether the deletion has been cancelled.
        # @return [true, false]
        def cancelled?
          @mutex.synchronize { @cancelled }
        end
      end

      # Sends a text message to a channel given its ID and the message's content.
      # @param channel [Channel, String, Integer] The channel, or its ID, to send something to.
      # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
      # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
      # @param embeds [Hash, OnyxCord::Webhooks::Embed, Array<Hash>, Array<OnyxCord::Webhooks::Embed> nil] The rich embed(s) to append to this message.
      # @param allowed_mentions [Hash, OnyxCord::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
      # @param message_reference [Message, String, Integer, Hash, nil] The message, or message ID, to reply to if any.
      # @param components [View, Array<Hash>] Interaction components to associate with this message.
      # @param flags [Integer] Flags for this message. Currently only SUPPRESS_EMBEDS (1 << 2), SUPPRESS_NOTIFICATIONS (1 << 12), and IS_COMPONENTS_V2 (1 << 15) can be set.
      # @param nonce [String, nil] A optional nonce in order to verify that a message was sent. Maximum of twenty-five characters.
      # @param enforce_nonce [true, false] Whether the nonce should be enforced and used for message de-duplication.
      # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
      # @return [Message] The message that was sent.
      def send_message(channel, content, tts = false, embeds = nil, attachments = nil, allowed_mentions = nil, message_reference = nil, components = nil, flags = 0, nonce = nil, enforce_nonce = false, poll = nil)
        channel = channel.resolve_id
        debug("Sending message to #{channel} with content '#{content}'")
        allowed_mentions = { parse: [] } if allowed_mentions == false
        message_reference = { message_id: message_reference.resolve_id } if message_reference.respond_to?(:resolve_id)
        embeds = (embeds.instance_of?(Array) ? embeds.map(&:to_hash) : [embeds&.to_hash]).compact
        flags = OnyxCord::MessageComponents.apply_v2_flag(flags, components)

        response = REST::Channel.create_message(token, channel, content, tts, embeds, nonce, attachments, allowed_mentions&.to_hash, message_reference, components, flags, enforce_nonce, poll&.to_h)
        Message.new(JSON.parse(response), self)
      end

      # Sends a text message to a channel given its ID and the message's content,
      # then deletes it after the specified timeout in seconds.
      # Returns a {TemporaryMessage} handle that can be used to cancel the deletion.
      # @param channel [Channel, String, Integer] The channel, or its ID, to send something to.
      # @param content [String] The text that should be sent as a message. It is limited to 2000 characters (Discord imposed).
      # @param timeout [Float] The amount of time in seconds after which the message sent will be deleted.
      # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
      # @param embeds [Hash, OnyxCord::Webhooks::Embed, Array<Hash>, Array<OnyxCord::Webhooks::Embed> nil] The rich embed(s) to append to this message.
      # @param attachments [Array<File>] Files that can be referenced in embeds via `attachment://file.png`
      # @param allowed_mentions [Hash, OnyxCord::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
      # @param message_reference [Message, String, Integer, nil] The message, or message ID, to reply to if any.
      # @param components [View, Array<Hash>] Interaction components to associate with this message.
      # @param flags [Integer] Flags for this message. Currently only SUPPRESS_EMBEDS (1 << 2), SUPPRESS_NOTIFICATIONS (1 << 12), and IS_COMPONENTS_V2 (1 << 15) can be set.
      # @param nonce [String, nil] A optional nonce in order to verify that a message was sent. Maximum of twenty-five characters.
      # @param enforce_nonce [true, false] Whether the nonce should be enforced and used for message de-duplication.
      # @param poll [Hash, Poll::Builder, Poll, nil] The poll that should be attached to this message.
      # @return [TemporaryMessage] A handle that can be used to cancel the deletion.
      def send_temporary_message(channel, content, timeout, tts = false, embeds = nil, attachments = nil, allowed_mentions = nil, message_reference = nil, components = nil, flags = 0, nonce = nil, enforce_nonce = false, poll = nil)
        message = send_message(channel, content, tts, embeds, attachments, allowed_mentions, message_reference, components, flags, nonce, enforce_nonce, poll)

        thread = Thread.new do
          Thread.current[:onyxcord_name] = "tmp-msg-#{message.id}"
          Internal::AsyncRuntime.sleep(timeout)
          message.delete
        rescue StandardError => e
          log_exception(e)
        end

        TemporaryMessage.new(message, thread)
      end

      # Sends a file to a channel. If it is an image, it will automatically be embedded.
      # @note This executes in a blocking way, so if you're sending long files, be wary of delays.
      # @param channel [Channel, String, Integer] The channel, or its ID, to send something to.
      # @param file [File] The file that should be sent.
      # @param caption [string] The caption for the file.
      # @param tts [true, false] Whether or not this file's caption should be sent using Discord text-to-speech.
      # @param filename [String] Overrides the filename of the uploaded file
      # @param spoiler [true, false] Whether or not this file should appear as a spoiler.
      # @example Send a file from disk
      #   bot.send_file(83281822225530880, File.open('rubytaco.png', 'r'))
      def send_file(channel, file, caption: nil, tts: false, filename: nil, spoiler: nil)
        if file.respond_to?(:read)
          if spoiler
            filename ||= File.basename(file.path)
            filename = "SPOILER_#{filename}" unless filename.start_with? 'SPOILER_'
          end
          file.define_singleton_method(:original_filename) { filename } if filename
          file.define_singleton_method(:path) { filename } if filename
        end

        channel = channel.resolve_id
        response = REST::Channel.upload_file(token, channel, file, caption: caption, tts: tts)
        Message.new(JSON.parse(response), self)
      end

# Gets the users, channels, roles and emoji from a string.
      # @param mentions [String] The mentions, which should look like `<@12314873129>`, `<#123456789>`, `<@&123456789>` or `<:name:126328:>`.
      # @param server [Server, nil] The server of the associated mentions.
      # @return [Array<User, Channel, Role, Emoji>]
      def parse_mentions(mentions, server = nil)
        return [] unless mentions.is_a?(String)

        array_to_return = []
        seen = { user: Set.new, channel: Set.new, role: Set.new, emoji: Set.new }

        while mentions.include?('<') && mentions.include?('>')
          mentions = mentions.split('<', 2)[1]
          next unless mentions.split('>', 2).first.length < mentions.split('<', 2).first.length

          mention = mentions.split('>', 2).first
          if /@!?(?<id>\d+)/ =~ mention
            next if seen[:user].include?(id)
            seen[:user].add(id)
            array_to_return << user(id) unless user(id).nil?
          elsif /#(?<id>\d+)/ =~ mention
            next if seen[:channel].include?(id)
            seen[:channel].add(id)
            array_to_return << channel(id, server) unless channel(id, server).nil?
          elsif /@&(?<id>\d+)/ =~ mention
            next if seen[:role].include?(id)
            seen[:role].add(id)
            if server
              array_to_return << server.role(id) unless server.role(id).nil?
            else
              @servers&.each_value do |element|
                array_to_return << element.role(id) unless element.role(id).nil?
              end
            end
          elsif /\A(?<animated>a)?:(?<name>\w+):(?<id>\d+)\z/ =~ mention
            next if seen[:emoji].include?(id)
            seen[:emoji].add(id)
            array_to_return << (emoji(id) || Emoji.new({ 'animated' => !animated.nil?, 'name' => name, 'id' => id }, self, nil))
          end
        end
        array_to_return
      end

      # Gets the user, channel, role or emoji from a string.
      # @param mention [String] The mention, which should look like `<@12314873129>`, `<#123456789>`, `<@&123456789>` or `<:name:126328:>`.
      # @param server [Server, nil] The server of the associated mentions.
      # @return [User, Channel, Role, Emoji]
      def parse_mention(mention, server = nil)
        parse_mentions(mention, server).first
      end

      # Join a thread
      # @param channel [Channel, Integer, String]
      def join_thread(channel)
        REST::Channel.join_thread(@token, channel.resolve_id)
        nil
      end

      # Leave a thread
      # @param channel [Channel, Integer, String]
      def leave_thread(channel)
        REST::Channel.leave_thread(@token, channel.resolve_id)
        nil
      end

      # Add a member to a thread
      # @param channel [Channel, Integer, String]
      # @param member [Member, Integer, String]
      def add_thread_member(channel, member)
        REST::Channel.add_thread_member(@token, channel.resolve_id, member.resolve_id)
        nil
      end

      # Remove a member from a thread
      # @param channel [Channel, Integer, String]
      # @param member [Member, Integer, String]
      def remove_thread_member(channel, member)
        REST::Channel.remove_thread_member(@token, channel.resolve_id, member.resolve_id)
        nil
      end

      # Makes the bot leave any groups with no recipients remaining
      def prune_empty_groups
        @channels.each_value do |channel|
          channel.leave_group if channel.group? && channel.recipients.empty?
        end
      end
    end
  end
end
