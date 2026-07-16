# frozen_string_literal: true

require 'onyxcord/webhooks/embeds'
require 'onyxcord/utils/message_components'

module OnyxCord::Webhooks
  # Sentinel value meaning "do not change this field" in edit operations.
  UNSET = Object.new.freeze

  # Maximum number of embeds per message (Discord limit).
  MAX_EMBEDS = 10

  # A class that acts as a builder for a webhook message object.
  class Builder
    # @param content [String] The content of the message.  May be 2000
    #   characters long at most.
    # @param username [String, nil] Override the webhook's default username.
    # @param avatar_url [String, nil] Override the webhook's default avatar.
    # @param tts [true, false] Whether this message should use text-to-speech.
    # @param file [File, nil] A file to send alongside the message.
    # @param embeds [Array<Embed, Hash>] Embeds to include.
    # @param allowed_mentions [AllowedMentions, Hash, nil] Mention restrictions.
    # @param poll [Poll, Poll::Builder, Hash, nil] A poll to include.
    # @param flags [Integer] Bitwise message flags.
    # @param thread_name [String, nil] Name of the new thread to create
    #   (forum / media channels only).
    # @param applied_tags [Array<String>, nil] Tags to apply to the thread
    #   (forum channels only).
    def initialize(content: '', username: nil, avatar_url: nil, tts: false, file: nil, embeds: [], allowed_mentions: nil, poll: nil, flags: 0, thread_name: nil, applied_tags: nil)
      @content = content
      @username = username
      @avatar_url = avatar_url
      @tts = tts
      @file = file
      @embeds = Array(embeds)
      self.allowed_mentions = allowed_mentions
      @poll = poll
      @flags = flags
      @thread_name = thread_name
      @applied_tags = applied_tags
    end

    # The content of the message.  May be 2000 characters long at most.
    # @return [String] the content of the message.
    attr_accessor :content

    # The username the webhook will display as.
    # @return [String, nil] the username.
    attr_accessor :username

    # The URL of an image file to be used as an avatar.
    # @return [String, nil] the avatar URL.
    attr_accessor :avatar_url

    # Whether this message should use text-to-speech.
    # @return [true, false] the TTS status.
    attr_accessor :tts

    # Message flags to send with this webhook payload.
    # @return [Integer] the message flags.
    attr_accessor :flags

    # Thread name to create (forum / media channels only).
    # @return [String, nil] the thread name.
    attr_accessor :thread_name

    # Tags to apply to the created thread (forum channels only).
    # @return [Array<String>, nil] the applied tags.
    attr_accessor :applied_tags

    # Enable Discord's Components V2 message flag.
    # @return [Builder] this builder.
    def components_v2!
      @flags = @flags.to_i | OnyxCord::MessageComponents::IS_COMPONENTS_V2
      self
    end

    alias has_components! components_v2!

    # @return [true, false] whether Components V2 is enabled on this payload.
    def components_v2?
      @flags.to_i.anybits?(OnyxCord::MessageComponents::IS_COMPONENTS_V2)
    end

    # Sets a file to be sent together with the message.
    #
    # Files and embeds may coexist.  The Discord API accepts both and
    # supports +attachment://+ references inside embed images.
    #
    # @param file [File, IO, String] A file to be sent.
    def file=(file)
      @file = file
    end

    # Adds an embed to this message.
    #
    # @param embed [Embed] The embed to add.
    def <<(embed)
      @embeds << embed
    end

    # Convenience method to add an embed using a block-style builder pattern.
    #
    # When called without a block the embed is returned unmodified — this
    # allows the one-liner +builder.add_embed(existing_embed)+.
    #
    # @example Add an embed to a message
    #   builder.add_embed do |embed|
    #     embed.title = 'Testing'
    #     embed.image = OnyxCord::Webhooks::EmbedImage.new(url: 'https://i.imgur.com/PcMltU7.jpg')
    #   end
    # @param embed [Embed, nil] The embed to start the building process with,
    #   or nil if one should be created anew.
    # @return [Embed] The created embed.
    def add_embed(embed = nil)
      embed ||= Embed.new
      yield(embed) if block_given?
      self << embed
      embed
    end

    # Convenience method to add a poll using a builder pattern.
    #
    # @example Add a poll to a message
    #   builder.poll(question: "Best Fruit?", duration: 48) do |poll|
    #     poll.answer(text: "Apple", emoji: "🍎")
    #     poll.answer(text: "Orange", emoji: "🍊")
    #     poll.answer(text: "Pomelo", emoji: "🍈")
    #   end
    # @param poll [Poll::Builder, Poll, Hash, nil] The poll to start the
    #   building process with, or nil if one should be created anew.
    # @return [Poll::Builder, Poll] The created poll.
    def add_poll(poll = nil, **kwargs)
      poll ||= OnyxCord::Poll::Builder.new(**kwargs)
      yield(poll) if block_given?
      @poll = poll
      poll
    end

    alias_method :poll, :add_poll

    # @return [File, nil] the file attached to this message.
    attr_reader :file

    # @return [Array<Embed>] the embeds attached to this message.
    attr_reader :embeds

    # @return [OnyxCord::AllowedMentions, Hash] Mentions that are allowed to
    #   ping in this message.
    attr_reader :allowed_mentions

    # Set the allowed mentions.
    #
    # @param value [AllowedMentions, Hash, nil] The allowed mentions config.
    # @raise [ArgumentError] if the value is not an AllowedMentions, Hash, or nil.
    def allowed_mentions=(value)
      if value.nil?
        @allowed_mentions = nil
      elsif value.is_a?(OnyxCord::AllowedMentions)
        @allowed_mentions = value
      elsif value.is_a?(Hash)
        require 'onyxcord/utils/allowed_mentions'
        @allowed_mentions = OnyxCord::AllowedMentions.new(**value)
      else
        raise ArgumentError, "allowed_mentions must be an AllowedMentions, Hash, or nil, got #{value.class}"
      end
    end

    # @return [Poll, Poll::Builder, Hash, nil] The poll attached to this
    #   message.
    attr_writer :poll

    # @return [Hash] a hash representation of the created message, for JSON
    #   format.
    def to_json_hash
      data = {
        content: @content,
        username: @username,
        avatar_url: @avatar_url,
        tts: @tts,
        embeds: serialize_embeds,
        allowed_mentions: @allowed_mentions&.to_hash,
        poll: @poll&.to_h,
        thread_name: @thread_name,
        applied_tags: @applied_tags
      }
      data[:flags] = @flags if @flags.to_i.positive?
      data
    end

    # Return a deep-frozen snapshot of the current payload.
    #
    # Unlike +to_json_hash+, the returned hash is deeply frozen so that
    # callers can hold a stable reference without worrying about the
    # builder being mutated.
    #
    # @return [Hash] a frozen deep copy of the JSON payload.
    def snapshot
      deep_freeze(to_json_hash)
    end

    # @return [Hash] a hash representation of the created message, for
    #   multipart format.
    def to_multipart_hash
      files = Array(@file)
      data = {
        content: @content,
        username: @username,
        avatar_url: @avatar_url,
        tts: @tts,
        embeds: serialize_embeds,
        allowed_mentions: @allowed_mentions&.to_hash,
        poll: @poll&.to_h,
        thread_name: @thread_name,
        applied_tags: @applied_tags,
        files: files
      }
      data[:flags] = @flags if @flags.to_i.positive?
      data
    end

    # Validate that the payload contains at least one meaningful field.
    # Discord rejects empty payloads with 400 Bad Request.
    #
    # This is a public method so callers can validate before sending.
    # It is NOT called automatically from to_json_hash because callers
    # may merge kwargs after serialization.
    def validate_payload!
      return if @file
      return if @poll
      return if @flags.to_i.positive?

      content_present = @content.respond_to?(:empty?) ? !@content.empty? : !!@content
      embeds_present = @embeds.respond_to?(:any?) ? @embeds.any? : !!@embeds

      return if !content_present && !embeds_present

      raise ArgumentError, 'Payload must contain at least one of: content, embeds, file, poll, or flags'
    end

    private

    # Validate that the payload contains at least one meaningful field.
    # Discord rejects empty payloads with 400 Bad Request.
    #
    # Skips validation when the builder is in its default state (empty
    # content, no embeds/file/poll/flags) — callers may merge kwargs
    # after serialization.
    def validate_payload!
      return if @file
      return if @poll
      return if @flags.to_i.positive?

      content_present = if @content.respond_to?(:empty?)
                          !@content.empty?
                        else
                          !!@content
                        end

      embeds_present = if @embeds.respond_to?(:any?)
                         @embeds.any?
                       else
                         !!@embeds
                       end

      # Both empty → default state, skip (kwargs may be merged later)
      return if !content_present && !embeds_present

      raise ArgumentError, 'Payload must contain at least one of: content, embeds, file, poll, or flags'
    end

    # Serialize embeds, validating each one against Discord limits.
    def serialize_embeds
      return nil if @embeds.nil?

      raise ArgumentError, "Too many embeds: #{@embeds.length} (max #{MAX_EMBEDS})" if @embeds.length > MAX_EMBEDS

      @embeds.map do |e|
        e.validate! if e.respond_to?(:validate!)
        e.respond_to?(:to_hash) ? e.to_hash : e
      end
    end

    # Deep-freeze a nested Hash/Array structure in-place and return it.
    def deep_freeze(obj)
      case obj
      when Hash
        obj.each_value { |v| deep_freeze(v) }
        obj.freeze
      when Array
        obj.each { |v| deep_freeze(v) }
        obj.freeze
      else
        obj.freeze if obj.respond_to?(:freeze)
        obj
      end
    end
  end

  # A builder for editing existing webhook messages.
  #
  # Unlike {Builder}, an EditBuilder uses a sentinel +UNSET+ value so that
  # only fields explicitly set by the caller are included in the payload.
  # This prevents the destructive behaviour where omitting a field would
  # reset it to its default (e.g. clearing +content+ by not setting it).
  #
  # Fields that are never valid for edits (+username+, +avatar_url+, +tts+,
  # +poll+) are excluded entirely.
  class EditBuilder
    # @return [String, UNSET] the message content, or UNSET if unchanged.
    attr_reader :content

    # @return [Array<Embed>, UNSET] the embeds, or UNSET if unchanged.
    attr_reader :embeds

    # @return [OnyxCord::AllowedMentions, Hash, UNSET] allowed mentions.
    attr_reader :allowed_mentions

    # @return [Integer, UNSET] message flags.
    attr_reader :flags

    # @return [File, IO, String, nil] a new file to attach (multipart edits).
    attr_accessor :file

    def initialize
      @content = UNSET
      @embeds = UNSET
      @allowed_mentions = UNSET
      @flags = UNSET
      @file = nil
      yield self if block_given?
    end

    # Set the message content.
    #
    # @param value [String, nil] The new content.  Pass +nil+ explicitly to
    #   clear the content field.
    def content=(value)
      @content = value
    end

    # Set the embeds for this message.
    #
    # @param value [Array<Embed, Hash>, nil] The new embeds.
    def embeds=(value)
      @embeds = value
    end

    # Add an embed to this message.
    #
    # @param embed [Embed, nil] The embed to start with, or nil.
    # @return [Embed] The embed.
    def add_embed(embed = nil)
      embed ||= Embed.new
      yield(embed) if block_given?
      @embeds = [] if @embeds.equal?(UNSET)
      @embeds << embed
      embed
    end

    # Set the allowed mentions.
    #
    # @param value [AllowedMentions, Hash, nil] The allowed mentions config.
    # @raise [ArgumentError] if the value is not an AllowedMentions, Hash, or nil.
    def allowed_mentions=(value)
      if value.nil?
        @allowed_mentions = nil
      elsif value.is_a?(OnyxCord::AllowedMentions)
        @allowed_mentions = value
      elsif value.is_a?(Hash)
        @allowed_mentions = OnyxCord::AllowedMentions.new(**value)
      else
        raise ArgumentError, "allowed_mentions must be an AllowedMentions, Hash, or nil, got #{value.class}"
      end
    end

    # Set the message flags.
    #
    # @param value [Integer, nil] The message flags.
    def flags=(value)
      @flags = value
    end

    # EditBuilder does not enforce minimum payload validation — edits can
    # clear all fields (e.g. remove all embeds).
    def validate_payload!; end

    # Return a deep-frozen snapshot of the current edit payload.
    #
    # @return [Hash] a frozen deep copy of the JSON payload.
    def snapshot
      deep_freeze(to_json_hash)
    end

    # @return [Hash] a hash representation of the edit payload.  Only
    #   fields that were explicitly set are included.
    def to_json_hash
      data = {}
      data[:content] = @content unless @content.equal?(UNSET)
      data[:embeds] = serialize_embeds unless @embeds.equal?(UNSET)
      data[:allowed_mentions] = @allowed_mentions&.to_hash unless @allowed_mentions.equal?(UNSET)
      data[:flags] = @flags unless @flags.equal?(UNSET)
      data
    end

    private

    def serialize_embeds
      return nil if @embeds.nil?

      embeds = Array(@embeds)
      raise ArgumentError, "Too many embeds: #{embeds.length} (max #{MAX_EMBEDS})" if embeds.length > MAX_EMBEDS

      embeds.map do |e|
        e.validate! if e.respond_to?(:validate!)
        e.respond_to?(:to_hash) ? e.to_hash : e
      end
    end

    # Deep-freeze a nested Hash/Array structure in-place and return it.
    def deep_freeze(obj)
      case obj
      when Hash
        obj.each_value { |v| deep_freeze(v) }
        obj.freeze
      when Array
        obj.each { |v| deep_freeze(v) }
        obj.freeze
      else
        obj.freeze if obj.respond_to?(:freeze)
        obj
      end
    end
  end
end
