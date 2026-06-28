# frozen_string_literal: true

require 'onyxcord/http'
require 'onyxcord/json'
require 'time'

require 'onyxcord/errors'
require 'onyxcord/rate_limiter/rest'

# List of methods representing endpoints in Discord's API
module OnyxCord::API
  # The base URL of the Discord REST API.
  APIBASE = 'https://discord.com/api/v9'

  # The URL of Discord's CDN
  CDN_URL = 'https://cdn.discordapp.com'

  module_function

  # @return [String] the currently used API base URL.
  def api_base
    @api_base || APIBASE
  end

  # Sets the API base URL to something.
  def api_base=(value)
    @api_base = value
  end

  # @return [String] the currently used CDN url
  def cdn_url
    @cdn_url || CDN_URL
  end

  # @return [String] the bot name, previously specified using {.bot_name=}.
  def bot_name
    @bot_name
  end

  # Sets the bot name to something. Used in {.user_agent}. For the bot's username, see {Profile#username=}.
  def bot_name=(value)
    @bot_name = value
  end

  # Changes the rate limit tracing behaviour. If rate limit tracing is on, a full backtrace will be logged on every RL
  # hit.
  # @param value [true, false] whether or not to enable rate limit tracing
  def trace=(value)
    @trace = value
  end

  # Generate a user agent identifying this requester as onyxcord.
  def user_agent
    # This particular string is required by the Discord devs.
    required = "DiscordBot (https://github.com/kruldevb/OnyxCord, v#{OnyxCord::VERSION})"
    @bot_name ||= ''

    "#{required} httpx/#{HTTPX::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL} onyxcord/#{OnyxCord::VERSION} #{@bot_name}"
  end

  # Resets all rate limit mutexes
  def reset_mutexes
    @rate_limiter = OnyxCord::RateLimiter::Rest.new
  end

  def rate_limiter
    @rate_limiter ||= OnyxCord::RateLimiter::Rest.new
  end

  def rate_limiter_stats
    rate_limiter.stats
  end

  # Wait a specified amount of time synchronised with the specified mutex.
  def sync_wait(time, mutex)
    mutex.synchronize { sleep time }
  end

  # Wait for a specified mutex to unlock and do nothing with it afterwards.
  def mutex_wait(mutex)
    mutex.lock
    mutex.unlock
  end

  # Performs a raw HTTP request using HTTPX.
  # @param type [Symbol] The type of HTTP request to use.
  # @param url [String] The URL to request.
  # @param body [String, Hash, nil] The request body.
  # @param headers [Hash] Additional headers.
  # @return [OnyxCord::HTTP::Response]
  def raw_request(type, url, body = nil, **headers)
    headers[:user_agent] = user_agent

    response = OnyxCord::HTTP.request(type, url, body, **headers)

    if response.code == 403
      noprm = OnyxCord::Errors::NoPermission.new
      noprm.define_singleton_method(:_response) { response }
      raise noprm, "The bot doesn't have the required permission to do this!"
    end

    # Retry on 502 Bad Gateway
    if response.code == 502
      OnyxCord::LOGGER.warn('Got a 502 while sending a request! Not a big deal, retrying the request')
      return raw_request(type, url, body, **headers)
    end

    response
  end

  # Make an API request, including rate limit handling.
  def request(key, major_parameter, type, *attributes)
    # Parse attributes: URL is first, body is second (if present), rest is headers hash
    url = attributes.shift
    headers_or_body = attributes

    # Separate body and headers from the positional args
    body = nil
    headers = {}

    headers_or_body.each do |arg|
      if arg.is_a?(Hash)
        headers.merge!(arg)
      elsif body.nil?
        body = arg
      end
    end

    # Extract content_type from headers for HTTPX
    content_type = headers.delete(:content_type)
    headers['content-type'] = 'application/json' if content_type == :json

    # Add user agent
    headers['user-agent'] = user_agent

    begin
      rate_limiter.before_request(key, major_parameter)

      response = nil
      begin
        response = OnyxCord::HTTP.request(type, url, body, **headers)

        if response.code == 403
          noprm = OnyxCord::Errors::NoPermission.new
          noprm.define_singleton_method(:_response) { response }
          raise noprm, "The bot doesn't have the required permission to do this!"
        end

        # Retry on 502
        if response.code == 502
          OnyxCord::LOGGER.warn('Got a 502 while sending a request! Not a big deal, retrying the request')
          return request(key, major_parameter, type, url, body, headers)
        end

        # Handle error status codes
        if response.code >= 400 && response.code != 429
          data = begin
            JSON.parse(response.body)
          rescue StandardError
            nil
          end

          raise "HTTP #{response.code}: #{response.body}" unless data

          err_klass = OnyxCord::Errors.error_class_for(data['code'] || 0)
          e = err_klass.new(data['message'], data['errors'])
          OnyxCord::LOGGER.error(e.full_message)
          raise e
        end
      rescue OnyxCord::Errors::NoPermission => e
        if e.respond_to?(:_response)
          response = e._response
        else
          OnyxCord::LOGGER.warn("NoPermission doesn't respond_to? _response!")
        end

        raise e
      ensure
        if response
          rate_limiter.record_response(key, major_parameter, response.headers)
        else
          OnyxCord::LOGGER.ratelimit('Response was nil before trying to preemptively rate limit!')
        end
      end
    rescue OnyxCord::Errors::CodeError => e
      raise if e.respond_to?(:code) && e.code != 429_000

      raise
    end

    # Handle 429 rate limiting
    if response&.code == 429
      trace("429 #{key} #{major_parameter}")
      rate_limiter.handle_rate_limit(key, major_parameter, response)
      return request(key, major_parameter, type, url, body, headers)
    end

    # Endpoints that use Elasticsearch can return a 202 when the index isn't ready yet. Wait the
    # amount of time indicated by the response body, and then recursively retry and return the request.
    if response&.code == 202 && response&.body
      body_data = JSON.parse(response.body)

      if body_data['code'] == 110_000
        case body_data['retry_after']
        when 0, 1, nil
          sleep(rand(4.5..5.0))
        else
          sleep(body_data['retry_after'])
        end

        return request(key, major_parameter, type, url, body, headers)
      end
    end

    response
  end

  # Handles pre-emptive rate limiting by waiting the given mutex by the difference of the Date header to the
  # X-Ratelimit-Reset header, thus making sure we don't get 429'd in any subsequent requests.
  def handle_preemptive_rl(headers, mutex, key)
    OnyxCord::LOGGER.ratelimit "RL bucket depletion detected! Date: #{headers[:date]} Reset: #{headers[:x_ratelimit_reset]}"
    delta = headers[:x_ratelimit_reset_after].to_f
    OnyxCord::LOGGER.warn("Locking RL mutex (key: #{key}) for #{delta} seconds pre-emptively")
    sync_wait(delta, mutex)
  end

  # Perform rate limit tracing. All this method does is log the current backtrace to the console with the `:ratelimit`
  # level.
  # @param reason [String] the reason to include with the backtrace.
  def trace(reason)
    unless @trace
      OnyxCord::LOGGER.debug("trace was called with reason #{reason}, but tracing is not enabled")
      return
    end

    OnyxCord::LOGGER.ratelimit("Trace (#{reason}):")

    caller.each do |str|
      OnyxCord::LOGGER.ratelimit(" #{str}")
    end
  end

  # Make an icon URL from server and icon IDs
  def icon_url(server_id, icon_id, format = 'webp')
    "#{cdn_url}/icons/#{server_id}/#{icon_id}.#{format}"
  end

  # Make an icon URL from application and icon IDs
  def app_icon_url(app_id, icon_id, format = 'webp')
    "#{cdn_url}/app-icons/#{app_id}/#{icon_id}.#{format}"
  end

  # Make a widget picture URL from server ID
  def widget_url(server_id, style = 'shield')
    "#{api_base}/guilds/#{server_id}/widget.png?style=#{style}"
  end

  # Make a splash URL from server and splash IDs
  def splash_url(server_id, splash_id, format = 'webp')
    "#{cdn_url}/splashes/#{server_id}/#{splash_id}.#{format}"
  end

  # Make a discovery splash URL from server and splash IDs
  def discovery_splash_url(server_id, splash_id, format = 'webp')
    "#{cdn_url}/discovery-splashes/#{server_id}/#{splash_id}.#{format}"
  end

  # Make a banner URL from server and banner IDs
  def banner_url(server_id, banner_id, format = 'webp')
    "#{cdn_url}/banners/#{server_id}/#{banner_id}.#{format}"
  end

  # Make an emoji icon URL from emoji ID
  def emoji_icon_url(emoji_id, format = 'webp')
    "#{cdn_url}/emojis/#{emoji_id}.#{format}"
  end

  # Make an asset URL from application and asset IDs
  def asset_url(application_id, asset_id, format = 'webp')
    "#{cdn_url}/app-assets/#{application_id}/#{asset_id}.#{format}"
  end

  # Make an achievement icon URL from application ID, achievement ID, and icon hash
  def achievement_icon_url(application_id, achievement_id, icon_hash, format = 'webp')
    "#{cdn_url}/app-assets/#{application_id}/achievements/#{achievement_id}/icons/#{icon_hash}.#{format}"
  end

  # @param role_id [String, Integer]
  # @param icon_hash [String]
  # @param format ['webp', 'png', 'jpeg']
  # @return [String]
  def role_icon_url(role_id, icon_hash, format = 'webp')
    "#{cdn_url}/role-icons/#{role_id}/#{icon_hash}.#{format}"
  end

  # make an avatar decoration URL from an avatar decoration ID.
  def avatar_decoration_url(avatar_decoration_id, format = 'png')
    "#{cdn_url}/avatar-decoration-presets/#{avatar_decoration_id}.#{format}"
  end

  # make a static nameplate URL from the nameplate asset.
  def static_nameplate_url(nameplate_asset, format = 'png')
    "#{cdn_url}/assets/collectibles/#{nameplate_asset.delete_suffix('/')}/static.#{format}"
  end

  # make a nameplate URL from the nameplate asset.
  def nameplate_url(nameplate_asset, format = 'webm')
    "#{cdn_url}/assets/collectibles/#{nameplate_asset.delete_suffix('/')}/asset.#{format}"
  end

  # make a server tag badge URL from a server ID and badge ID.
  def server_tag_badge_url(server_id, badge_id, format = 'webp')
    "#{cdn_url}/guild-tag-badges/#{server_id}/#{badge_id}.#{format}"
  end

  # make a scheduled event cover URL from a scheduled event ID and a cover ID.
  def scheduled_event_cover_url(scheduled_event_id, cover_id, format = 'webp', size = nil)
    "#{cdn_url}/guild-events/#{scheduled_event_id}/#{cover_id}.#{format}#{"?size=#{size}" if size}"
  end

  # make a cover image URL from application and cover IDs.
  def app_cover_url(app_id, cover_id, format = 'webp')
    "#{cdn_url}/app-icons/#{app_id}/#{cover_id}.#{format}"
  end

  # make a team icon URL from team and icon IDs.
  def team_icon_url(team_id, icon_id, format = 'webp')
    "#{cdn_url}/team-icons/#{team_id}/#{icon_id}.#{format}"
  end

  # Change an OAuth application's properties
  # @deprecated Please use {Application#update_current_application} instead.
  def update_oauth_application(token, name, redirect_uris, description = '', icon = nil)
    request(
      :oauth2_applications,
      nil,
      :put,
      "#{api_base}/oauth2/applications",
      { name: name, redirect_uris: redirect_uris, description: description, icon: icon }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the bot's OAuth application's information
  def oauth_application(token)
    request(
      :oauth2_applications_me,
      nil,
      :get,
      "#{api_base}/applications/@me",
      Authorization: token
    )
  end

  # Get the gateway to be used
  def gateway(token)
    request(
      :gateway,
      nil,
      :get,
      "#{api_base}/gateway",
      Authorization: token
    )
  end

  # Get the gateway to be used, with additional information for sharding and
  # session start limits
  def gateway_bot(token)
    request(
      :gateway_bot,
      nil,
      :get,
      "#{api_base}/gateway/bot",
      Authorization: token
    )
  end

  # Get a list of available voice regions
  def voice_regions(token)
    request(
      :voice_regions,
      nil,
      :get,
      "#{api_base}/voice/regions",
      Authorization: token,
      content_type: :json
    )
  end
end

OnyxCord::API.reset_mutexes
