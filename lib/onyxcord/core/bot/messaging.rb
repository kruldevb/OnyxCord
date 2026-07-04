# frozen_string_literal: true

module OnyxCord
  class Bot
    module Messaging
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
      def send_temporary_message(channel, content, timeout, tts = false, embeds = nil, attachments = nil, allowed_mentions = nil, message_reference = nil, components = nil, flags = 0, nonce = nil, enforce_nonce = false, poll = nil)
        Internal::AsyncRuntime.async do
          message = send_message(channel, content, tts, embeds, attachments, allowed_mentions, message_reference, components, flags, nonce, enforce_nonce, poll)
          Internal::AsyncRuntime.sleep(timeout)
          message.delete
        end

        nil
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
      # @param server [Server, nil] The server of the associated mentions. (recommended for role parsing, to speed things up)
      # @return [Array<User, Channel, Role, Emoji>] The array of users, channels, roles and emoji identified by the mentions, or `nil` if none exists.
      def parse_mentions(mentions, server = nil)
        array_to_return = []
        # While possible mentions may be in message
        while mentions.include?('<') && mentions.include?('>')
          # Removing all content before the next possible mention
          mentions = mentions.split('<', 2)[1]
          # Locate the first valid mention enclosed in `<...>`, otherwise advance to the next open `<`
          next unless mentions.split('>', 2).first.length < mentions.split('<', 2).first.length

          # Store the possible mention value to be validated with RegEx
          mention = mentions.split('>', 2).first
          if /@!?(?<id>\d+)/ =~ mention
            array_to_return << user(id) unless user(id).nil?
          elsif /#(?<id>\d+)/ =~ mention
            array_to_return << channel(id, server) unless channel(id, server).nil?
          elsif /@&(?<id>\d+)/ =~ mention
            if server
              array_to_return << server.role(id) unless server.role(id).nil?
            else
              @servers.each_value do |element|
                array_to_return << element.role(id) unless element.role(id).nil?
              end
            end
          elsif /(?<animated>^a|^${0}):(?<name>\w+):(?<id>\d+)/ =~ mention
            array_to_return << (emoji(id) || Emoji.new({ 'animated' => animated != '', 'name' => name, 'id' => id }, self, nil))
          end
        end
        array_to_return
      end

      # Gets the user, channel, role or emoji from a string.
      # @param mention [String] The mention, which should look like `<@12314873129>`, `<#123456789>`, `<@&123456789>` or `<:name:126328:>`.
      # @param server [Server, nil] The server of the associated mention. (recommended for role parsing, to speed things up)
      # @return [User, Channel, Role, Emoji] The user, channel, role or emoji identified by the mention, or `nil` if none exists.
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
