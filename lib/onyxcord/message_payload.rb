# frozen_string_literal: true

require 'onyxcord/message_components'
require 'onyxcord/upload'

module OnyxCord
  module MessagePayload
    MAX_ATTACHMENTS = 10
    MAX_EMBEDS = 10
    KEEP = :keep

    module_function

    def attachment_payload(attachments)
      uploads(attachments).map.with_index { |upload, index| { id: index, filename: upload.filename } }
    end

    def multipart_body(body, attachments)
      parts = uploads(attachments).map.with_index do |upload, index|
        {
          name: "files[#{index}]",
          value: upload,
          filename: upload.filename,
          content_type: upload.content_type || 'application/octet-stream'
        }
      end

      parts << { name: 'payload_json', value: body.to_json }
    end

    def validate!(content: nil, embeds: nil, components: nil, flags: nil, attachments: nil, poll: nil)
      validate_limit!('attachments', attachments, MAX_ATTACHMENTS)
      validate_limit!('embeds', embeds, MAX_EMBEDS)
      validate_components_v2!(content, embeds, components, flags, poll)
    end

    def edit_body(content, embeds)
      content_keep = content == KEEP
      embeds_keep = embeds == KEEP
      content_given = !content_keep && !content.nil?
      embeds_given = !embeds_keep && !embeds.nil?
      body = {}
      body[:content] = content if !content_keep && (content_given || embeds_given)
      body[:embeds] = embeds_given ? embeds : [] if !embeds_keep && (embeds_given || content_given)
      body
    end

    def uploads(attachments)
      Array(attachments).map { |attachment| OnyxCord::Upload.wrap(attachment) }
    end

    def validate_limit!(name, values, max)
      return if values.nil? || Array(values).length <= max

      raise ArgumentError, "#{name} cannot exceed #{max} elements"
    end

    def validate_components_v2!(content, embeds, components, flags, poll)
      return unless components_v2?(components, flags)
      return unless present?(content) || present?(embeds) || present?(poll)

      raise ArgumentError, 'Components V2 messages cannot include content, embeds, or poll'
    end

    def components_v2?(components, flags)
      OnyxCord::MessageComponents.components_v2?(components) ||
        (OnyxCord::MessageComponents.flag_value(flags) & OnyxCord::MessageComponents::IS_COMPONENTS_V2).positive?
    end

    def present?(value)
      return false if value.nil?
      return false if value == KEEP
      return !value.empty? if value.respond_to?(:empty?)

      true
    end
  end
end
