# frozen_string_literal: true

require 'uri'
require 'base64'
require 'onyxcord/internal/http'
require 'onyxcord/internal/json'
require 'onyxcord/rest/client'

require 'onyxcord/webhooks/builder'

module OnyxCord::Webhooks
  # A client for a particular webhook added to a Discord channel.
  #
  # Authentication is by webhook token embedded in the URL.  All HTTP
  # traffic is routed through {OnyxCord::REST::Client} so that rate limits,
  # retries and error mapping are handled consistently with the rest of the
  # library.
  class Client
    # Allowed image MIME types for avatars (per Discord Image Data).
    ALLOWED_AVATAR_MIME = %w[image/jpeg image/png image/gif image/webp].freeze

    # Maximum avatar payload size (bytes) before Base64 encoding.
    MAX_AVATAR_BYTES = 256 * 1024

    # Canonical Discord webhook host.
    DISCORD_HOST = 'discord.com'

    # Regex that matches a valid Discord webhook path.
    # Captures: (1) API version, (2) webhook ID, (3) webhook token.
    WEBHOOK_PATH_RE = %r{\A/api/v(\d+)/webhooks/(\d+)/([^?/]+)\z}.freeze

    # Create a new webhook client.
    #
    # @param url [String, nil] Full webhook URL.  Mutually exclusive with
    #   +id+ / +token+.
    # @param id [String, Integer, nil] Webhook snowflake ID.
    # @param token [String, nil] Webhook authorisation token.
    # @param rest_client [OnyxCord::REST::Client, nil] REST client to use
    #   for HTTP traffic.  Falls back to the default singleton when nil.
    def initialize(url: nil, id: nil, token: nil, rest_client: nil)
      @rest_client = rest_client

      if url
        validate_webhook_url!(url)
        extract_id_token_from_url!(url)
      elsif id && token
        @webhook_id = id.to_s
        @webhook_token = token.to_s
      else
        raise ArgumentError, 'Provide either url or both id and token'
      end
    end

    # Executes the webhook this client points to with the given data.
    #
    # @param builder [Builder, nil] The builder to start out with, or nil if
    #   one should be created anew.
    # @param wait [true, false] Whether Discord should wait for the message
    #   to be successfully received by clients (default: +true+ for safe
    #   error handling).  When +false+ Discord returns 204 No Content and
    #   delivery errors are silently swallowed.
    # @param components [View, Array, nil] Component payload.
    # @param thread_id [String, Integer, nil] Target thread for the execution.
    # @param flags [Integer, nil] Message flags override.
    # @param has_components [true, false] Legacy flag; prefer +components_v2+.
    # @param components_v2 [true, false] Force IS_COMPONENTS_V2 flag.
    # @param thread_name [String, nil] Create a new thread with this name
    #   (forum / media channels only).  Ignored on regular channels.
    # @param applied_tags [Array<String>, nil] Tags to apply to the created
    #   thread (forum channels only).
    # @yield [builder, view] Gives the builder and view to the block.
    # @yieldparam builder [Builder] The builder given as a parameter.
    # @yieldparam view [View] The component view.
    # @return [OnyxCord::Internal::HTTP::Response] the response returned by Discord.
    def execute(builder = nil, wait = true, components = nil, thread_id: nil, flags: nil, has_components: false, components_v2: false, thread_name: nil, applied_tags: nil)
      validate_builder!(builder) unless builder.nil?

      builder ||= Builder.new
      view = View.new

      yield(builder, view) if block_given?

      components ||= view
      force_v2 = has_components || components_v2

      # Apply builder's thread_name / applied_tags if not overridden
      thread_name = builder.thread_name if thread_name.nil? && builder.respond_to?(:thread_name)
      applied_tags = builder.applied_tags if applied_tags.nil? && builder.respond_to?(:applied_tags)

      if builder.file
        post_multipart(builder, components, wait, thread_id, flags: flags, has_components: force_v2, thread_name: thread_name, applied_tags: applied_tags)
      else
        post_json(builder, components, wait, thread_id, flags: flags, has_components: force_v2, thread_name: thread_name, applied_tags: applied_tags)
      end
    end

    # Modify this webhook's properties.
    #
    # When authenticated with the webhook token (this client), the endpoint
    # is "Modify Webhook with Token" which does *not* accept +channel_id+.
    #
    # @param name [String, nil] The default name.
    # @param avatar [String, #read, nil] The new avatar data.
    # @return [OnyxCord::Internal::HTTP::Response] the response returned by Discord.
    def modify(name: nil, avatar: nil)
      data = { name: name, avatar: avatarise(avatar) }.compact
      request(:patch, '', body: data.to_json, headers: { 'content-type' => 'application/json' })
    end

    # Delete this webhook.
    #
    # The "Delete Webhook with Token" endpoint does not accept an audit-log
    # reason header — that is only available when authenticated with a bot
    # token.
    #
    # @return [OnyxCord::Internal::HTTP::Response] the response returned by Discord.
    # @note This is permanent and cannot be undone.
    def delete
      request(:delete, '')
    end

    # Edit a message from this webhook.
    #
    # @param message_id [String, Integer] The ID of the message to edit.
    # @param builder [Builder, EditBuilder, nil] The builder to start out
    #   with, or nil if one should be created anew.
    # @param content [String, nil] The message content.
    # @param embeds [Array<Embed, Hash>, nil]
    # @param allowed_mentions [AllowedMentions, Hash, nil]
    # @param components [View, Array, nil]
    # @param flags [Integer, nil]
    # @param thread_id [String, Integer, nil]
    # @param with_components [true, false] Whether to include the
    #   +with_components+ query parameter (required for non-owned webhooks).
    # @return [OnyxCord::Internal::HTTP::Response] the response returned by Discord.
    # @example Edit message content
    #   client.edit_message(message_id, content: 'goodbye world!')
    # @example Edit a message via builder
    #   client.edit_message(message_id) do |builder|
    #     builder.add_embed do |e|
    #       e.description = 'Hello World!'
    #     end
    #   end
    # @example Edit with a new file attachment
    #   client.edit_message(message_id, file: File.open('image.png'))
    def edit_message(message_id, builder: nil, content: nil, embeds: nil, allowed_mentions: nil, components: nil, flags: nil, thread_id: nil, with_components: false, file: nil, retain_attachments: nil)
      edit = builder || EditBuilder.new

      yield edit if block_given?

      # Merge caller-level file into builder
      edit.instance_variable_set(:@file, file) if file

      components_payload = components.nil? ? nil : View.component_payload(components)
      data = edit.to_json_hash
      builder_flags = data[:flags] if data.is_a?(Hash)
      flags = View.apply_v2_flag(flags || builder_flags, components_payload, force: with_components)

      payload = data.merge(
        content: content,
        embeds: normalize_embeds(embeds),
        allowed_mentions: allowed_mentions&.to_hash,
        components: components_payload,
        flags: flags
      ).compact

      query = {}
      query[:thread_id] = thread_id if thread_id
      query[:with_components] = true if with_components && components_payload&.any?

      # Multipart edit: builder has a file or caller passed file:
      if edit.file
        files = Array(edit.file).compact
        attachments_meta = build_edit_attachments(files, retain_attachments)

        payload.delete(:attachments) if payload[:attachments]
        multipart = build_multipart_parts(payload, files)

        # Add attachment retention metadata
        multipart << { name: 'attachments', value: attachments_meta.to_json } if attachments_meta.any?

        request(:patch, "/messages/#{message_id}", body: multipart, query: query)
      else
        payload[:attachments] = retain_attachments if retain_attachments&.any?
        request(:patch, "/messages/#{message_id}", body: payload.to_json, query: query, headers: { 'content-type' => 'application/json' })
      end
    end

    # Delete a message created by this webhook.
    #
    # @param message_id [String, Integer] The ID of the message to delete.
    # @param thread_id [String, Integer, nil] Thread the message resides in.
    # @return [OnyxCord::Internal::HTTP::Response] the response returned by Discord.
    def delete_message(message_id, thread_id: nil)
      query = thread_id ? { thread_id: thread_id } : {}
      request(:delete, "/messages/#{message_id}", query: query)
    end

    # Retrieve a message created by this webhook.
    #
    # @param message_id [String, Integer] The ID of the message.
    # @param thread_id [String, Integer, nil] Thread the message resides in.
    # @return [OnyxCord::Internal::HTTP::Response] the response returned by Discord.
    def get_message(message_id, thread_id: nil)
      query = thread_id ? { thread_id: thread_id } : {}
      request(:get, "/messages/#{message_id}", query: query)
    end

    # @return [String] the webhook ID.
    def webhook_id
      @webhook_id
    end

    # Inspect-friendly representation that redacts the token.
    def inspect
      "#<#{self.class.name} webhook_id=#{@webhook_id} token=[token]>"
    end

    private

    # ------------------------------------------------------------------ #
    #  URL helpers                                                        #
    # ------------------------------------------------------------------ #

    # Build the canonical base URL for this webhook.
    def base_url
      "https://#{DISCORD_HOST}/api/v10/webhooks/#{@webhook_id}/#{@webhook_token}"
    end

    # Build a full request URL from a relative path and optional query.
    #
    # @param path [String] Relative path (e.g. +"/messages/123"+).
    # @param query [Hash] Query parameters to append.
    # @param wait [true, false, nil] +wait+ parameter override.
    # @param thread_id [String, Integer, nil] +thread_id+ parameter.
    # @param with_components [true, false] +with_components+ parameter.
    # @param thread_name [String, nil] +thread_name+ parameter (forum channels).
    # @param applied_tags [Array<String>, nil] +applied_tags+ parameter (forum channels).
    # @return [String] The fully qualified URL.
    def build_url(path, query: {}, wait: nil, thread_id: nil, with_components: false, thread_name: nil, applied_tags: nil)
      uri = URI.parse("#{base_url}#{path}")

      # Start with any existing query params from the base URL (should be none
      # for a canonical URL, but guard against user-supplied URLs).
      existing = parse_query(uri.query)

      # Explicit parameters from the call-site win over existing query params.
      merged = existing.merge(compact_query(
        'wait' => wait,
        'thread_id' => thread_id,
        'with_components' => (with_components ? true : nil),
        'thread_name' => thread_name,
        'applied_tags' => applied_tags&.join(',')
      ))
      merged.merge!(query) if query.any?

      q = URI.encode_www_form(merged)
      uri.query = q unless q.empty?
      uri.to_s
    end

    # Parse a query string into a Hash with string keys.
    def parse_query(qs)
      return {} if qs.nil? || qs.empty?
      URI.decode_www_form(qs).to_h
    end

    # Compact a hash, removing nil values.
    def compact_query(hash)
      hash.compact
    end

    # ------------------------------------------------------------------ #
    #  Request routing                                                    #
    # ------------------------------------------------------------------ #

    # Route an HTTP request through the REST client with rate-limit and
    # error handling.
    #
    # @param type [Symbol] HTTP method (:get, :post, :patch, :delete).
    # @param path [String] Relative path appended to the webhook base URL.
    # @param body [String, Hash, nil] Request body.
    # @param query [Hash] Additional query parameters (encoded into the URL).
    # @param headers [Hash] Extra headers.
    # @param wait [true, false, nil] +wait+ parameter.
    # @param thread_id [String, Integer, nil] +thread_id+ parameter.
    # @param with_components [true, false] +with_components+ parameter.
    # @param thread_name [String, nil] +thread_name+ parameter (forum channels).
    # @param applied_tags [Array<String>, nil] +applied_tags+ parameter (forum channels).
    # @return [OnyxCord::Internal::HTTP::Response]
    def request(type, path, body: nil, query: {}, headers: {}, wait: nil, thread_id: nil, with_components: false, thread_name: nil, applied_tags: nil)
      url = build_url(path, query: query, wait: wait, thread_id: thread_id, with_components: with_components, thread_name: thread_name, applied_tags: applied_tags)

      rest_client.request(
        :webhook,
        @webhook_id,
        type,
        url,
        body: body,
        headers: headers
      )
    end

    # @return [OnyxCord::REST::Client] the REST client used for requests.
    def rest_client
      @rest_client || OnyxCord::REST.default_client
    end

    # ------------------------------------------------------------------ #
    #  URL validation (SSRF protection)                                   #
    # ------------------------------------------------------------------ #

    # Validate that a webhook URL is safe to use.
    #
    # @param url [String] The URL to validate.
    # @raise [ArgumentError] if the URL is invalid or points to a non-Discord host.
    def validate_webhook_url!(url)
      # Reject control characters before URI parsing (which would raise a
      # different error on control chars).
      raise ArgumentError, 'Webhook URL contains control characters' if url.match?(/[\x00-\x1f\x7f]/)

      uri = URI.parse(url)

      raise ArgumentError, 'Webhook URL must use HTTPS' unless uri.scheme == 'https'
      raise ArgumentError, 'Webhook URL must not contain userinfo' if uri.user || uri.password
      raise ArgumentError, "Webhook URL host must be #{DISCORD_HOST}, got: #{uri.host}" unless uri.host == DISCORD_HOST

      path = uri.path || ''
      unless path.match?(WEBHOOK_PATH_RE)
        raise ArgumentError, "Webhook URL path does not match expected pattern: #{path}"
      end
    end

    # Extract webhook ID and token from a validated URL.
    def extract_id_token_from_url!(url)
      uri = URI.parse(url)
      match = (uri.path || '').match(WEBHOOK_PATH_RE)
      raise ArgumentError, 'Could not extract webhook ID and token from URL' unless match

      @webhook_id = match[2]
      @webhook_token = match[3]
    end

    # ------------------------------------------------------------------ #
    #  Builder validation                                                 #
    # ------------------------------------------------------------------ #

    # Validate that an object satisfies the builder duck-type contract.
    def validate_builder!(builder)
      return if builder.respond_to?(:to_json_hash) || builder.respond_to?(:to_multipart_hash)

      raise TypeError, 'builder must respond to #to_json_hash or #to_multipart_hash'
    end

    # ------------------------------------------------------------------ #
    #  Payload helpers                                                    #
    # ------------------------------------------------------------------ #

    # Normalize an embeds array, copying hashes to prevent external mutation.
    def normalize_embeds(embeds)
      return nil if embeds.nil?
      return [] if embeds.empty?

      Array(embeds).map do |e|
        e.respond_to?(:to_hash) ? e.to_hash : e.dup
      end
    end

    # Convert an avatar to API-ready data.
    #
    # @param avatar [String, #read] Avatar data.
    # @return [String, nil] Base64-encoded data URI, or nil.
    def avatarise(avatar)
      return avatar unless avatar.respond_to?(:read)

      data = avatar.read
      if data.bytesize > MAX_AVATAR_BYTES
        raise ArgumentError, "Avatar too large: #{data.bytesize} bytes (max #{MAX_AVATAR_BYTES})"
      end

      # Detect MIME type from magic bytes
      mime = detect_image_mime(data)
      raise ArgumentError, "Unsupported avatar image type: #{mime || 'unknown'}" unless ALLOWED_AVATAR_MIME.include?(mime)

      "data:#{mime};base64,#{Base64.strict_encode64(data)}"
    end

    # Detect image MIME type from magic bytes.
    def detect_image_mime(data)
      return nil if data.nil? || data.bytesize < 4

      bytes = data.bytes

      # PNG: 89 50 4E 47
      return 'image/png' if bytes[0..3] == [0x89, 0x50, 0x4E, 0x47]

      # JPEG: FF D8 FF
      return 'image/jpeg' if bytes[0..2] == [0xFF, 0xD8, 0xFF]

      # GIF: 47 49 46 38
      return 'image/gif' if bytes[0..3] == [0x47, 0x49, 0x46, 0x38]

      # WebP: starts with RIFF....WEBP
      if data.bytesize >= 12 &&
         bytes[0..3] == [0x52, 0x49, 0x46, 0x46] &&
         bytes[8..11] == [0x57, 0x45, 0x42, 0x50]
        return 'image/webp'
      end

      nil
    end

    # ------------------------------------------------------------------ #
    #  POST helpers                                                       #
    # ------------------------------------------------------------------ #

    def post_json(builder, components, wait, thread_id, flags: nil, has_components: false, thread_name: nil, applied_tags: nil)
      components = View.component_payload(components)
      data = builder.to_json_hash
      builder_flags = data[:flags] if data.is_a?(Hash)
      flags = View.apply_v2_flag(flags || builder_flags, components, force: has_components)

      # Components V2: omit incompatible fields
      if OnyxCord::MessageComponents.components_v2?(components)
        data.delete(:content)
        data.delete(:embeds)
        data.delete(:poll)
        data.delete(:tts)
      end

      # thread_name / applied_tags are query params, not body fields
      data.delete(:thread_name)
      data.delete(:applied_tags)

      data[:components] = components if components.any?
      data[:flags] = flags unless flags.nil?

      request(:post, '', body: data.to_json, query: { 'wait' => wait },
              headers: { 'content-type' => 'application/json' },
              with_components: components.any?,
              thread_name: thread_name, applied_tags: applied_tags)
    end

    def post_multipart(builder, components, wait, thread_id, flags: nil, has_components: false, thread_name: nil, applied_tags: nil)
      components = View.component_payload(components)
      data = builder.to_multipart_hash
      builder_flags = data[:flags] if data.is_a?(Hash)
      flags = View.apply_v2_flag(flags || builder_flags, components, force: has_components)

      # Components V2: omit incompatible fields
      if OnyxCord::MessageComponents.components_v2?(components)
        data.delete(:content)
        data.delete(:embeds)
        data.delete(:poll)
        data.delete(:tts)
      end

      # thread_name / applied_tags are query params, not body fields
      data.delete(:thread_name)
      data.delete(:applied_tags)

      data[:components] = components if components.any?
      data[:flags] = flags unless flags.nil?

      # Extract files from the data hash
      files = data.delete(:files) || []
      file = data.delete(:file)
      files = Array(file) if files.empty? && file
      files = files.compact

      # Build Discord multipart format: files[n] + payload_json + attachments
      parts = build_multipart_parts(data, files)

      request(:post, '', body: parts, query: { 'wait' => wait },
              with_components: components.any?,
              thread_name: thread_name, applied_tags: applied_tags)
    end

    # Build multipart form parts in Discord's expected format:
    #   files[0], files[1], ... (binary file parts)
    #   payload_json (JSON string with all non-file fields)
    #   attachments (JSON array mapping file indices to metadata)
    def build_multipart_parts(payload, files)
      attachments = []
      parts = []

      files.each_with_index do |file, index|
        upload = ::OnyxCord::Upload.wrap(file)
        filename = upload.filename

        parts << {
          name: "files[#{index}]",
          value: upload,
          filename: filename,
          content_type: upload.content_type
        }

        attachments << {
          id: index,
          filename: filename
        }
      end

      # payload_json contains all non-file fields as a JSON string
      parts << {
        name: 'payload_json',
        value: payload.to_json
      }

      # attachments metadata tells Discord how to map file indices
      parts << {
        name: 'attachments',
        value: attachments.to_json
      } if attachments.any?

      parts
    end

    # Build the attachments metadata array for an edit request.
    #
    # Combines retained attachment IDs (from the original message) with
    # newly uploaded file entries so that Discord keeps the old files
    # alongside the new ones.
    #
    # @param files [Array] New files being uploaded.
    # @param retain_attachments [Array<Hash>, nil] Original attachment
    #   descriptors to keep (each must include an +id+).
    # @return [Array<Hash>] Combined attachments metadata array.
    def build_edit_attachments(files, retain_attachments)
      meta = []

      # Retained attachments get sequential IDs starting after the new files
      next_id = files.size

      Array(retain_attachments).each do |att|
        next unless att.is_a?(Hash) && att[:id]

        meta << {
          id: next_id,
          filename: att[:filename] || att['filename']
        }
        next_id += 1
      end

      meta
    end
  end
end
