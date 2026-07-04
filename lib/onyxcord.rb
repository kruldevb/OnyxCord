# frozen_string_literal: true

require 'base64'
require 'mime/types'
require 'zeitwerk'
require_relative 'onyxcord/core/version'
require_relative 'onyxcord/core/logger'

# All onyxcord functionality, to be extended by other files
module OnyxCord
  Thread.current[:onyxcord_name] = 'main'

  # The default debug logger used by onyxcord.
  LOGGER = Logger.new(ENV.fetch('ONYXCORD_FANCY_LOG', false))

  # The Unix timestamp Discord IDs are based on
  DISCORD_EPOCH = 1_420_070_400_000

  # Used to declare what events you wish to recieve from Discord.
  # @see https://discord.com/developers/docs/topics/gateway#gateway-intents
  INTENTS = {
    servers: 1 << 0,
    server_members: 1 << 1,
    server_bans: 1 << 2,
    server_emojis: 1 << 3,
    server_integrations: 1 << 4,
    server_webhooks: 1 << 5,
    server_invites: 1 << 6,
    server_voice_states: 1 << 7,
    server_presences: 1 << 8,
    server_messages: 1 << 9,
    server_message_reactions: 1 << 10,
    server_message_typing: 1 << 11,
    direct_messages: 1 << 12,
    direct_message_reactions: 1 << 13,
    direct_message_typing: 1 << 14,
    message_content: 1 << 15,
    server_scheduled_events: 1 << 16,
    server_message_polls: 1 << 24,
    direct_message_polls: 1 << 25
  }.freeze

  INTENT_ALIASES = {
    guilds: :servers,
    guild_members: :server_members,
    guild_bans: :server_bans,
    guild_emojis: :server_emojis,
    guild_integrations: :server_integrations,
    guild_webhooks: :server_webhooks,
    guild_invites: :server_invites,
    guild_voice_states: :server_voice_states,
    guild_presences: :server_presences,
    guild_messages: :server_messages,
    guild_message_reactions: :server_message_reactions,
    guild_message_typing: :server_message_typing,
    guild_scheduled_events: :server_scheduled_events,
    guild_message_polls: :server_message_polls
  }.freeze

  MINIMAL_INTENTS = INTENTS.values_at(:servers, :server_messages, :direct_messages).reduce(&:|)

  # All available intents
  ALL_INTENTS = INTENTS.values.reduce(&:|)

  # All unprivileged intents
  # @see https://discord.com/developers/docs/topics/gateway#privileged-intents
  UNPRIVILEGED_INTENTS = ALL_INTENTS & ~(INTENTS[:server_members] | INTENTS[:server_presences] | INTENTS[:message_content])

  # No intents
  NO_INTENTS = 0

  # Compares two objects based on IDs - either the objects' IDs are equal, or one object is equal to the other's ID.
  def self.id_compare?(one_id, other)
    other.respond_to?(:resolve_id) ? (one_id.resolve_id == other.resolve_id) : (one_id == other)
  end

  # @deprecated Please use {OnyxCord.id_compare?}
  singleton_class.alias_method :id_compare, :id_compare?

  # The maximum length a Discord message can have
  CHARACTER_LIMIT = 2000

  # For creating timestamps with {timestamp}
  # @see https://discord.com/developers/docs/reference#message-formatting-timestamp-styles
  TIMESTAMP_STYLES = {
    short_time: 't', # 16:20
    long_time: 'T', # 16:20:30
    short_date: 'd', # 20/04/2021
    long_date: 'D', # 20 April 2021
    short_datetime: 'f', # 20 April 2021 16:20
    long_datetime: 'F', # Tuesday, 20 April 2021 16:20
    relative: 'R', # 2 months ago
    simple_datetime: 's', # 20/04/2021, 16:20
    medium_datetime: 'S' # 20/04/2021, 16:20:30
  }.freeze

  # Splits a message into chunks of 2000 characters. Attempts to split by lines if possible.
  # @param msg [String] The message to split.
  # @return [Array<String>] the message split into chunks
  def self.split_message(msg)
    return [] if msg.empty?

    chunks = []
    current = +''

    msg.lines.each do |line|
      if line.length > CHARACTER_LIMIT
        chunks << current unless current.empty?
        current = +''
        rest = line
        until rest.empty?
          break chunks << rest if rest.length <= CHARACTER_LIMIT

          chunk = rest[0, CHARACTER_LIMIT]
          split_at = chunk.rindex(' ')
          split_at = split_at ? split_at + 1 : CHARACTER_LIMIT
          chunks << rest[0, split_at]
          rest = rest[split_at..]
        end
      elsif current.length + line.length <= CHARACTER_LIMIT
        current << line
      else
        chunks << current
        current = line.dup
      end
    end

    chunks << current unless current.empty?
    chunks[-1] = chunks[-1].delete_suffix("\n") if chunks[-1]
    chunks
  end

  # @param time [Time, Integer] The time to create the timestamp from, or a unix timestamp integer.
  # @param style [Symbol, String] One of the keys from {TIMESTAMP_STYLES} or a string with the style.
  # @return [String]
  # @example
  #   OnyxCord.timestamp(Time.now, :short_time)
  #   # => "<t:1632146954:t>"
  def self.timestamp(time, style = nil)
    if style.nil?
      "<t:#{time.to_i}>"
    else
      "<t:#{time.to_i}:#{TIMESTAMP_STYLES[style] || style}>"
    end
  end

  # A utility method to base64 encode a file like object using its mime type.
  # @param file [File, #read] A file like object that responds to #read.
  # @return [String] The file object encoded as base64 image data.
  def self.encode64(file)
    path_method = %i[original_filename path local_path].find { |method| file.respond_to?(method) }

    raise ArgumentError, 'File object must respond to original_filename, path, or local path.' unless path_method
    raise ArgumentError, 'File object must respond to read.' unless file.respond_to?(:read)

    mime_type = MIME::Types.type_for(file.__send__(path_method)).first&.to_s || 'image/jpeg'
    "data:#{mime_type};base64,#{Base64.encode64(file.read).strip}"
  end
end

# In onyxcord, Integer and {String} are monkey-patched to allow for easy resolution of IDs
class Integer
  # @return [Integer] The Discord ID represented by this integer, i.e. the integer itself
  def resolve_id
    self
  end
end

# In onyxcord, {Integer} and String are monkey-patched to allow for easy resolution of IDs
class String
  # @return [Integer] The Discord ID represented by this string, i.e. the string converted to an integer
  def resolve_id
    to_i
  end
end

# Zeitwerk setup. Files with legacy public constants are ignored and loaded by
# their aggregators below; renaming every public class is a separate breaking cut.
loader = Zeitwerk::Loader.for_gem
loader.tag = 'onyxcord'
loader.push_dir("#{__dir__}/onyxcord", namespace: OnyxCord)

loader.ignore(
  "#{__dir__}/onyxcord/core/version.rb",
  "#{__dir__}/onyxcord/core/logger.rb",
  "#{__dir__}/onyxcord/internal",
  "#{__dir__}/onyxcord/utils",
  "#{__dir__}/onyxcord/models.rb",
  "#{__dir__}/onyxcord/models",
  "#{__dir__}/onyxcord/events",
  "#{__dir__}/onyxcord/rest",
  "#{__dir__}/onyxcord/webhooks.rb",
  "#{__dir__}/onyxcord/webhooks",
  "#{__dir__}/onyxcord/voice",
  "#{__dir__}/onyxcord/interactions/internal",
  "#{__dir__}/onyxcord/application_commands.rb",
  "#{__dir__}/onyxcord/application_commands",
  "#{__dir__}/onyxcord/interactions",
  "#{__dir__}/onyxcord/cache",
  "#{__dir__}/onyxcord/gateway",
  "#{__dir__}/onyxcord/container.rb",
  "#{__dir__}/onyxcord/bot.rb",
  "#{__dir__}/onyxcord/commands"
)

loader.setup

%w[
  internal/json
  internal/http
  internal/async_runtime
  internal/event_executor
  internal/message_payload
  internal/upload
  internal/websocket
  internal/gateway/opcodes
  internal/gateway/session
  internal/rate_limiter/rest
  internal/rate_limiter/async_rest
  internal/rate_limiter/gateway
  core/errors
  core/configuration
  utils/id_object
  utils/permissions
  utils/allowed_mentions
  utils/colour_rgb
  utils/paginator
  utils/message_components
  rest/client
  rest/routes/channel
  rest/routes/server
  rest/routes/invite
  rest/routes/user
  rest/routes/webhook
  rest/routes/interaction
  rest/routes/application
  models
  cache/manager
  await
  container
  internal/event_bus
  gateway/client
  application_commands
  interactions/registry
  voice/client
  webhooks
  bot
  commands/bot
].each { |path| require_relative "onyxcord/#{path}" }

loader.eager_load if ENV['ONYXCORD_EAGER_LOAD']
