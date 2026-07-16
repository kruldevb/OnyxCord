# frozen_string_literal: true

require 'onyxcord/internal/http'
require 'onyxcord/internal/json'
require 'onyxcord/internal/async_runtime'
require 'time'

require 'onyxcord/core/errors'
require_relative '../internal/rate_limiter/rest'
require_relative '../internal/rate_limiter/async_rest'

# List of methods representing endpoints in Discord's API
module OnyxCord::REST
  # The base URL of the Discord REST API.
  APIBASE = 'https://discord.com/api/v10'

  # The URL of Discord's CDN
  CDN_URL = 'https://cdn.discordapp.com'

  # HTTP methods that are safe to retry automatically.
  IDEMPOTENT_METHODS = %i[get put delete head options trace].freeze

  # Maximum number of retries for transient HTTP errors (5xx).
  MAX_RETRIES = 3

  # Maximum number of retries for rate-limited responses (429 / 202 with code 110000).
  MAX_RATE_LIMIT_RETRIES = 5

  # Maximum elapsed time (seconds) before giving up on retries.
  MAX_RETRY_ELAPSED = 60

  # Base delay for exponential backoff (seconds).
  BACKOFF_BASE = 0.5

  # Maximum backoff delay cap (seconds).
  BACKOFF_CAP = 32.0

  # Maximum X-Audit-Log-Reason length in bytes (UTF-8 encoded, per Discord API).
  MAX_AUDIT_LOG_REASON_BYTES = 512

  # Regex matching sensitive tokens that should be redacted in logs.
  SENSITIVE_TOKEN_REGEX = /(?:Bot\s+)?[\w\-]{24,}\.[\w\-]{6}\.[\w\-_]{27,}|Bearer\s+[\w\-]+/i.freeze

  # Allowed CDN image formats.
  CDN_FORMATS = %w[webp png jpeg gif].freeze

  # Per-instance REST client. Each bot or application should have its own client
  # to avoid sharing rate limit state, token validity, and configuration.
  #
  # @example Two bots in the same process
  #   bot_a = OnyxCord::REST::Client.new(api_base: 'https://discord.com/api/v10')
  #   bot_b = OnyxCord::REST::Client.new(api_base: 'https://discord.com/api/v10')
  #   bot_a.request(:gateway, nil, :get, "#{bot_a.api_base}/gateway", headers: { Authorization: token_a })
  #   bot_b.request(:gateway, nil, :get, "#{bot_b.api_base}/gateway", headers: { Authorization: token_b })
  class Client
    attr_reader :api_base, :cdn_url, :bot_name

    def initialize(api_base: APIBASE, cdn_url: CDN_URL, bot_name: nil)
      @api_base = api_base
      @cdn_url = cdn_url
      @bot_name = bot_name
      @trace = false
      @token_invalid = false
      @rate_limiter = ::OnyxCord::Internal::RateLimiter::Rest.new
      @async_rate_limiter = ::OnyxCord::Internal::RateLimiter::AsyncRest.new
    end

    # @return [String] the currently used API base URL.
    def api_base
      @api_base || APIBASE
    end

    # Sets the API base URL. Validates that the URL uses HTTPS (except in test environments).
    def api_base=(value)
      uri = URI.parse(value)
      unless uri.scheme == 'https' || ENV['ONYXCORD_TEST']
        raise ArgumentError, "api_base must use HTTPS, got: #{uri.scheme}"
      end
      @api_base = value
    end

    # @return [String] the currently used CDN url
    def cdn_url
      @cdn_url || CDN_URL
    end

    # Sets the CDN URL.
    def cdn_url=(value)
      @cdn_url = value
    end

    # @return [String] the bot name
    def bot_name
      @bot_name
    end

    # Sets the bot name to something. Used in {#user_agent}.
    def bot_name=(value)
      @bot_name = value
    end

    # Changes the rate limit tracing behaviour.
    def trace=(value)
      @trace = value
    end

    # Returns true if tracing is enabled.
    def trace?
      @trace == true
    end

    # Returns true if the token has been invalidated (401 received).
    def token_invalid?
      @token_invalid == true
    end

    # Resets the token invalid state (e.g. after token rotation).
    def reset_token_state!
      @token_invalid = false
    end

    # Generate a user agent identifying this requester as onyxcord.
    def user_agent
      required = "DiscordBot (https://github.com/kruldevb/OnyxCord, v#{OnyxCord::VERSION})"
      name = @bot_name || ''
      "#{required} httpx/#{HTTPX::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL} onyxcord/#{OnyxCord::VERSION} #{name}"
    end

    # Resets all rate limit mutexes.
    def reset_mutexes
      @rate_limiter = ::OnyxCord::Internal::RateLimiter::Rest.new
      @async_rate_limiter = ::OnyxCord::Internal::RateLimiter::AsyncRest.new
    end

    def rate_limiter
      @rate_limiter
    end

    def async_rate_limiter
      @async_rate_limiter
    end

    def rate_limiter_stats
      @rate_limiter.stats
    end

    def async_rate_limiter_stats
      @async_rate_limiter.stats
    end

    # Build the X-Audit-Log-Reason header value.
    def audit_log_reason_header(reason)
      return nil if reason.nil? || reason.empty?

      encoded = URI.encode_www_form_component(reason)
      if encoded.bytesize > MAX_AUDIT_LOG_REASON_BYTES
        raise ArgumentError, "Audit log reason too long: #{encoded.bytesize} bytes (max #{MAX_AUDIT_LOG_REASON_BYTES})"
      end
      encoded
    end

    # Compute exponential backoff delay with jitter.
    def backoff_delay(attempt)
      base = [BACKOFF_BASE * (2**attempt), BACKOFF_CAP].min
      base + rand * base * 0.25
    end

    # Validate a Discord snowflake (ID) value.
    def validate_snowflake(value)
      return value if value.nil?

      str = value.to_s
      if str.empty? || !str.match?(/\A\d+\z/)
        raise ArgumentError, "Invalid snowflake: #{value.inspect}"
      end
      str
    end

    # Sanitize a URL for logging, removing tokens and sensitive query parameters.
    def sanitize_url_for_log(url)
      url.to_s
         .sub(%r{/webhooks/\d+/[^?]+}, '/webhooks/\1/[token]')
         .sub(%r{/interactions/\d+/[^/]+}, '/interactions/\1/[token]')
         .gsub(SENSITIVE_TOKEN_REGEX, '[REDACTED]')
    end

    # Performs a raw HTTP request using HTTPX with iterative retry and exponential backoff.
    def raw_request(type, url, body = nil, **headers)
      headers[:user_agent] = user_agent

      retries = 0
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      loop do
        response = ::OnyxCord::Internal::HTTP.request(type, url, body, **headers)

        unless response.code == 502
          return response
        end

        retries += 1
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        if retries >= MAX_RETRIES || elapsed >= MAX_RETRY_ELAPSED
          OnyxCord::LOGGER.warn("Giving up after #{retries} retries (#{elapsed.round(2)}s elapsed) on 502")
          return response
        end

        delay = backoff_delay(retries - 1)
        OnyxCord::LOGGER.warn("Got a 502, retrying in #{delay.round(2)}s (attempt #{retries}/#{MAX_RETRIES})")
        OnyxCord::Internal::AsyncRuntime.sleep(delay)
      end
    end

    # Make an API request, including rate limit handling.
    def request(key, major_parameter, type, url, body: nil, headers: {})
      if Async::Task.current?
        request_async(key, major_parameter, type, url, body: body, headers: headers)
      else
        OnyxCord::Internal::AsyncRuntime.run { request_async(key, major_parameter, type, url, body: body, headers: headers) }
      end
    end

    # Async version of request.
    def request_async(key, major_parameter, type, url, body: nil, headers: {})
      raise OnyxCord::Errors::InvalidAuthenticationError, 'Token has been invalidated (401 received). Rotate token and call reset_token_state! to retry.' if token_invalid?

      headers['content-type'] = 'application/json' if headers.delete(:content_type) == :json
      headers['user-agent'] = user_agent

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rate_limit_retries = 0
      transient_retries = 0

      response = begin
        loop do
          begin
            @async_rate_limiter.before_request(key, major_parameter)

            response = ::OnyxCord::Internal::HTTP.request(type, url, body, **headers)

            @async_rate_limiter.record_response(key, major_parameter, response.headers)
          rescue StandardError => e
            transient_retries += 1
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

            unless transient_retries < MAX_RETRIES && elapsed < MAX_RETRY_ELAPSED
              raise
            end

            delay = backoff_delay(transient_retries - 1)
            OnyxCord::LOGGER.warn("Temporary HTTP failure (#{e.class}), retrying in #{delay.round(2)}s")
            OnyxCord::Internal::AsyncRuntime.sleep(delay)
            next
          end

          # Circuit breaker: stop immediately on 401
          if response.code == 401
            @token_invalid = true
            OnyxCord::LOGGER.error('Token is invalid (HTTP 401). No further requests will be sent until reset_token_state! is called.')
            break
          end

          # Handle rate limits (429)
          if response.code == 429
            rate_limit_retries += 1
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

            unless rate_limit_retries < MAX_RATE_LIMIT_RETRIES && elapsed < MAX_RETRY_ELAPSED
              OnyxCord::LOGGER.error("Rate limit exceeded after #{rate_limit_retries} retries")
              break
            end

            trace("429 #{key} #{major_parameter}")
            @async_rate_limiter.handle_rate_limit(key, major_parameter, response)
            next
          end

          # Handle gateway startup rate limit (202 with code 110000)
          if response.code == 202 && response.body
            body_data = JSON.parse(response.body) rescue nil

            if body_data && body_data['code'] == 110_000
              rate_limit_retries += 1
              elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

              unless rate_limit_retries < MAX_RATE_LIMIT_RETRIES && elapsed < MAX_RETRY_ELAPSED
                OnyxCord::LOGGER.error("Gateway startup rate limit exceeded after #{rate_limit_retries} retries")
                break
              end

              retry_after = case body_data['retry_after']
                            when 0, 1, nil
                              rand(4.5..5.0)
                            else
                              [body_data['retry_after'].to_f, 30].min
                            end
              OnyxCord::Internal::AsyncRuntime.sleep(retry_after)
              next
            end
          end

          # Handle transient errors (5xx) — only for idempotent methods
          if IDEMPOTENT_METHODS.include?(type) && [500, 502, 503, 504].include?(response.code)
            transient_retries += 1
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

            unless transient_retries < MAX_RETRIES && elapsed < MAX_RETRY_ELAPSED
              break
            end

            delay = backoff_delay(transient_retries - 1)
            OnyxCord::LOGGER.warn("Got HTTP #{response.code}, retrying in #{delay.round(2)}s (attempt #{transient_retries})")
            OnyxCord::Internal::AsyncRuntime.sleep(delay)
            next
          end

          break
        end

        response
      end

      # Raise appropriate error for error responses
      if response.code == 401
        @token_invalid = true
        raise OnyxCord::Errors::InvalidAuthenticationError
      end

      if response.code == 403
        data = begin
          JSON.parse(response.body)
        rescue StandardError
          nil
        end

        route = request_diagnostic(type, url, body, headers)

        if data
          err_klass = OnyxCord::Errors.error_class_for(data['code'] || 0)
          e = err_klass.new(data['message'], data['errors'], status: response.code, headers: response.headers, route: route, body: response.body, response: response)
          OnyxCord::LOGGER.error(e.full_message)
          raise e
        end

        noprm = OnyxCord::Errors::NoPermission.new(
          "The bot doesn't have the required permission to do this!",
          status: response.code,
          headers: response.headers,
          route: route,
          body: response.body,
          response: response
        )
        noprm.define_singleton_method(:_response) { response }
        raise noprm
      end

      if response.code >= 400 && response.code != 429
        data = begin
          JSON.parse(response.body)
        rescue StandardError
          nil
        end

        route = request_diagnostic(type, url, body, headers)
        unless data
          raise OnyxCord::Errors::HTTPError.new(
            "HTTP #{response.code} #{route}: #{response.body}",
            status: response.code,
            headers: response.headers,
            route: route,
            body: response.body,
            response: response
          )
        end

        err_klass = OnyxCord::Errors.error_class_for(data['code'] || 0)
        e = err_klass.new(data['message'], data['errors'], status: response.code, headers: response.headers, route: route, body: response.body, response: response)
        if e.is_a?(OnyxCord::Errors::UnknownMessage)
          OnyxCord::LOGGER.warn('Ignoring stale Discord message reference.')
        else
          OnyxCord::LOGGER.error(e.full_message)
        end
        raise e
      end

      response
    end

    # Perform rate limit tracing.
    def trace(reason)
      unless @trace
        OnyxCord::LOGGER.debug("trace was called with reason #{reason}, but tracing is not enabled")
        return
      end

      OnyxCord::LOGGER.ratelimit("Trace (#{reason}):")
      caller.each { |str| OnyxCord::LOGGER.ratelimit(" #{str}") }
    end

    def request_diagnostic(type, url, body, headers)
      clean_url = sanitize_url_for_log(url)
      header_keys = headers.keys.map(&:to_s).sort.join(',')
      body_info = if body.is_a?(Hash)
                    body.map do |key, value|
                      path = value.path if value.respond_to?(:path)
                      detail = path ? "file:#{File.basename(path)}" : value.to_s.bytesize
                      "#{key}=#{detail}"
                    end.join(',')
                  else
                    body.nil? ? 'nil' : "#{body.class}:#{body.to_s.bytesize}"
                  end

      "(#{type.to_s.upcase} #{clean_url} headers=#{header_keys} body=#{body_info})"
    rescue StandardError => e
      "(diagnostic_failed=#{e.class}: #{e.message})"
    end

    # --- CDN URL helpers (nil-safe) ---

    def icon_url(server_id, icon_id, format = 'webp')
      return nil if server_id.nil? || icon_id.nil?
      "#{cdn_url}/icons/#{server_id}/#{icon_id}.#{format}"
    end

    def app_icon_url(app_id, icon_id, format = 'webp')
      return nil if app_id.nil? || icon_id.nil?
      "#{cdn_url}/app-icons/#{app_id}/#{icon_id}.#{format}"
    end

    def widget_url(server_id, style = 'shield')
      return nil if server_id.nil?
      "#{api_base}/guilds/#{server_id}/widget.png?style=#{style}"
    end

    def splash_url(server_id, splash_id, format = 'webp')
      return nil if server_id.nil? || splash_id.nil?
      "#{cdn_url}/splashes/#{server_id}/#{splash_id}.#{format}"
    end

    def discovery_splash_url(server_id, splash_id, format = 'webp')
      return nil if server_id.nil? || splash_id.nil?
      "#{cdn_url}/discovery-splashes/#{server_id}/#{splash_id}.#{format}"
    end

    def banner_url(server_id, banner_id, format = 'webp')
      return nil if server_id.nil? || banner_id.nil?
      "#{cdn_url}/banners/#{server_id}/#{banner_id}.#{format}"
    end

    def emoji_icon_url(emoji_id, format = 'webp')
      return nil if emoji_id.nil?
      "#{cdn_url}/emojis/#{emoji_id}.#{format}"
    end

    def asset_url(application_id, asset_id, format = 'webp')
      return nil if application_id.nil? || asset_id.nil?
      "#{cdn_url}/app-assets/#{application_id}/#{asset_id}.#{format}"
    end

    def achievement_icon_url(application_id, achievement_id, icon_hash, format = 'webp')
      return nil if application_id.nil? || achievement_id.nil? || icon_hash.nil?
      "#{cdn_url}/app-assets/#{application_id}/achievements/#{achievement_id}/icons/#{icon_hash}.#{format}"
    end

    def role_icon_url(role_id, icon_hash, format = 'webp')
      return nil if role_id.nil? || icon_hash.nil?
      "#{cdn_url}/role-icons/#{role_id}/#{icon_hash}.#{format}"
    end

    def avatar_decoration_url(avatar_decoration_id, format = 'png')
      return nil if avatar_decoration_id.nil?
      "#{cdn_url}/avatar-decoration-presets/#{avatar_decoration_id}.#{format}"
    end

    def static_nameplate_url(nameplate_asset, format = 'png')
      return nil if nameplate_asset.nil?
      "#{cdn_url}/assets/collectibles/#{nameplate_asset.delete_suffix('/')}/static.#{format}"
    end

    def nameplate_url(nameplate_asset, format = 'webm')
      return nil if nameplate_asset.nil?
      "#{cdn_url}/assets/collectibles/#{nameplate_asset.delete_suffix('/')}/asset.#{format}"
    end

    def server_tag_badge_url(server_id, badge_id, format = 'webp')
      return nil if server_id.nil? || badge_id.nil?
      "#{cdn_url}/guild-tag-badges/#{server_id}/#{badge_id}.#{format}"
    end

    def scheduled_event_cover_url(scheduled_event_id, cover_id, format = 'webp', size = nil)
      return nil if scheduled_event_id.nil? || cover_id.nil?
      "#{cdn_url}/guild-events/#{scheduled_event_id}/#{cover_id}.#{format}#{"?size=#{size}" if size}"
    end

    def app_cover_url(app_id, cover_id, format = 'webp')
      return nil if app_id.nil? || cover_id.nil?
      "#{cdn_url}/app-icons/#{app_id}/#{cover_id}.#{format}"
    end

    def team_icon_url(team_id, icon_id, format = 'webp')
      return nil if team_id.nil? || icon_id.nil?
      "#{cdn_url}/team-icons/#{team_id}/#{icon_id}.#{format}"
    end
  end

  # --- Module-level facade for backward compatibility ---
  # These delegate to the default client instance. Route files continue to call
  # OnyxCord::REST.request(...) without changes.

  module_function

  # Returns the default REST client instance.
  def default_client
    @default_client ||= Client.new
  end

  # Replace the default client (e.g. after configuration change).
  def default_client=(client)
    @default_client = client
  end

  def api_base
    default_client.api_base
  end

  def api_base=(value)
    default_client.api_base = value
  end

  def cdn_url
    default_client.cdn_url
  end

  def cdn_url=(value)
    default_client.cdn_url = value
  end

  def bot_name
    default_client.bot_name
  end

  def bot_name=(value)
    default_client.bot_name = value
  end

  def trace=(value)
    default_client.trace = value
  end

  def token_invalid?
    default_client.token_invalid?
  end

  def reset_token_state!
    default_client.reset_token_state!
  end

  def user_agent
    default_client.user_agent
  end

  def reset_mutexes
    default_client.reset_mutexes
  end

  def rate_limiter
    default_client.rate_limiter
  end

  def async_rate_limiter
    default_client.async_rate_limiter
  end

  def rate_limiter_stats
    default_client.rate_limiter_stats
  end

  def async_rate_limiter_stats
    default_client.async_rate_limiter_stats
  end

  def audit_log_reason_header(reason)
    default_client.audit_log_reason_header(reason)
  end

  def backoff_delay(attempt)
    default_client.backoff_delay(attempt)
  end

  def validate_snowflake(value)
    default_client.validate_snowflake(value)
  end

  def sanitize_url_for_log(url)
    default_client.sanitize_url_for_log(url)
  end

  def raw_request(type, url, body = nil, **headers)
    default_client.raw_request(type, url, body, **headers)
  end

  def request(key, major_parameter, type, url, body: nil, headers: {})
    default_client.request(key, major_parameter, type, url, body: body, headers: headers)
  end

  def request_async(key, major_parameter, type, url, body: nil, headers: {})
    default_client.request_async(key, major_parameter, type, url, body: body, headers: headers)
  end

  def trace(reason)
    default_client.trace(reason)
  end

  def request_diagnostic(type, url, body, headers)
    default_client.request_diagnostic(type, url, body, headers)
  end

  # CDN URL helpers delegate to default client
  def icon_url(server_id, icon_id, format = 'webp')
    default_client.icon_url(server_id, icon_id, format)
  end

  def app_icon_url(app_id, icon_id, format = 'webp')
    default_client.app_icon_url(app_id, icon_id, format)
  end

  def widget_url(server_id, style = 'shield')
    default_client.widget_url(server_id, style)
  end

  def splash_url(server_id, splash_id, format = 'webp')
    default_client.splash_url(server_id, splash_id, format)
  end

  def discovery_splash_url(server_id, splash_id, format = 'webp')
    default_client.discovery_splash_url(server_id, splash_id, format)
  end

  def banner_url(server_id, banner_id, format = 'webp')
    default_client.banner_url(server_id, banner_id, format)
  end

  def emoji_icon_url(emoji_id, format = 'webp')
    default_client.emoji_icon_url(emoji_id, format)
  end

  def asset_url(application_id, asset_id, format = 'webp')
    default_client.asset_url(application_id, asset_id, format)
  end

  def achievement_icon_url(application_id, achievement_id, icon_hash, format = 'webp')
    default_client.achievement_icon_url(application_id, achievement_id, icon_hash, format)
  end

  def role_icon_url(role_id, icon_hash, format = 'webp')
    default_client.role_icon_url(role_id, icon_hash, format)
  end

  def avatar_decoration_url(avatar_decoration_id, format = 'png')
    default_client.avatar_decoration_url(avatar_decoration_id, format)
  end

  def static_nameplate_url(nameplate_asset, format = 'png')
    default_client.static_nameplate_url(nameplate_asset, format)
  end

  def nameplate_url(nameplate_asset, format = 'webm')
    default_client.nameplate_url(nameplate_asset, format)
  end

  def server_tag_badge_url(server_id, badge_id, format = 'webp')
    default_client.server_tag_badge_url(server_id, badge_id, format)
  end

  def scheduled_event_cover_url(scheduled_event_id, cover_id, format = 'webp', size = nil)
    default_client.scheduled_event_cover_url(scheduled_event_id, cover_id, format, size)
  end

  def app_cover_url(app_id, cover_id, format = 'webp')
    default_client.app_cover_url(app_id, cover_id, format)
  end

  def team_icon_url(team_id, icon_id, format = 'webp')
    default_client.team_icon_url(team_id, icon_id, format)
  end

  # Legacy module-level convenience methods (deprecated)
  # @deprecated Please use {Client#update_oauth_application} or create a client instance.
  def update_oauth_application(token, name, redirect_uris, description = '', icon = nil)
    default_client.request(
      :oauth2_applications, nil, :put, "#{api_base}/oauth2/applications",
      body: { name: name, redirect_uris: redirect_uris, description: description, icon: icon }.to_json,
      headers: { Authorization: "Bot #{token}", content_type: :json }
    )
  end

  def oauth_application(token)
    default_client.request(
      :oauth2_applications_me, nil, :get, "#{api_base}/applications/@me",
      headers: { Authorization: "Bot #{token}" }
    )
  end

  def gateway(token)
    default_client.request(
      :gateway, nil, :get, "#{api_base}/gateway",
      headers: { Authorization: "Bot #{token}" }
    )
  end

  def gateway_bot(token)
    default_client.request(
      :gateway_bot, nil, :get, "#{api_base}/gateway/bot",
      headers: { Authorization: "Bot #{token}" }
    )
  end

  def voice_regions(token)
    default_client.request(
      :voice_regions, nil, :get, "#{api_base}/voice/regions",
      headers: { Authorization: "Bot #{token}", content_type: :json }
    )
  end
end

OnyxCord::REST.reset_mutexes
