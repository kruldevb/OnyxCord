# frozen_string_literal: true

# Top-level namespace for the OnyxCord Discord framework.
module OnyxCord
  # Runtime defaults for OnyxCord bots.
  class Configuration
    MODES = %i[raw hybrid object].freeze
    EXECUTORS = %i[pool inline].freeze

    CACHE_PRESETS = {
      none: {
        users: false,
        voice_regions: false,
        servers: false,
        channels: false,
        pm_channels: false,
        thread_members: false,
        server_previews: false
      },
      minimal: {
        users: false,
        voice_regions: false,
        servers: true,
        channels: true,
        pm_channels: false,
        thread_members: false,
        server_previews: false
      },
      lean: {
        users: false,
        voice_regions: false,
        servers: true,
        channels: true,
        pm_channels: true,
        thread_members: false,
        server_previews: false
      },
      full: {
        users: true,
        voice_regions: true,
        servers: true,
        channels: true,
        pm_channels: true,
        thread_members: true,
        server_previews: true
      }
    }.freeze

    # Stores maximum limits for each LRU cache entity type.
    class CacheSizes
      VALID_KEYS = %i[servers channels users pm_channels thread_members server_previews].freeze
      MAX_SIZE = 1_000_000

      attr_reader :servers, :channels, :users, :pm_channels, :thread_members, :server_previews

      def initialize
        @servers = 1000
        @channels = 10_000
        @users = 50_000
        @pm_channels = 1000
        @thread_members = 5000
        @server_previews = 100
      end

      %i[servers channels users pm_channels thread_members server_previews].each do |name|
        define_method("#{name}=") do |value|
          validate_value!(name, value)
          instance_variable_set(:"@#{name}", value)
        end
      end

      def [](key)
        key = key.to_sym
        raise ArgumentError, "Unknown CacheSizes key: #{key.inspect}" unless VALID_KEYS.include?(key)

        send(key)
      end

      def []=(key, value)
        key = key.to_sym
        raise ArgumentError, "Unknown CacheSizes key: #{key.inspect}" unless respond_to?("#{key}=")

        validate_value!(key, value)
        send("#{key}=", value)
      end

      def to_h
        {
          servers: @servers,
          channels: @channels,
          users: @users,
          pm_channels: @pm_channels,
          thread_members: @thread_members,
          server_previews: @server_previews
        }
      end

      def dup
        copy = self.class.new
        to_h.each { |k, v| copy[k] = v }
        copy
      end

      private

      def validate_value!(key, value)
        return if value.nil?

        unless value.is_a?(Integer)
          raise ArgumentError, "#{key} cache size must be an Integer or nil, got #{value.class}"
        end

        if value.negative?
          raise ArgumentError, "#{key} cache size must be non-negative, got #{value}"
        end

        return unless value > MAX_SIZE

        raise ArgumentError, "#{key} cache size #{value} exceeds maximum #{MAX_SIZE}"
      end
    end

    attr_accessor :mode, :cache, :cache_sizes, :event_executor, :event_workers, :event_queue_size

    def initialize
      @mode = :hybrid
      @cache = :minimal
      @cache_sizes = CacheSizes.new
      @event_executor = :pool
      @event_workers = 4
      @event_queue_size = nil
    end

    def dup
      copy = self.class.new
      copy.mode = @mode
      copy.cache = @cache.is_a?(Hash) ? @cache.dup : @cache
      copy.cache_sizes = @cache_sizes.dup
      copy.event_executor = @event_executor
      copy.event_workers = @event_workers
      copy.event_queue_size = @event_queue_size
      copy
    end

    def normalize_mode(value = @mode)
      mode = (value || @mode).to_sym
      return mode if MODES.include?(mode)

      raise ArgumentError, "Unknown OnyxCord mode: #{value.inspect}"
    end

    def normalize_event_executor(value = @event_executor)
      executor = (value || @event_executor).to_sym
      return executor if EXECUTORS.include?(executor)

      raise ArgumentError, "Unknown event executor: #{value.inspect}"
    end

    def normalize_event_workers(value = @event_workers)
      workers = Integer(value || @event_workers)
      raise ArgumentError, 'event_workers must be greater than zero' unless workers.positive?

      workers
    end

    def normalize_event_queue_size(value = @event_queue_size)
      return nil if value.nil?

      size = Integer(value)
      raise ArgumentError, 'event_queue_size must be greater than zero' unless size.positive?

      size
    end

    def normalize_cache(value = @cache)
      cache = value.nil? ? @cache : value

      case cache
      when Hash
        known = CACHE_PRESETS[:none].keys
        transformed = cache.transform_keys(&:to_sym)
        unknown = transformed.keys - known
        raise ArgumentError, "Unknown cache keys: #{unknown.join(', ')}" if unknown.any?

        CACHE_PRESETS[:none].merge(transformed)
      else
        preset = cache.to_sym
        raise ArgumentError, "Unknown cache preset: #{cache.inspect}" unless CACHE_PRESETS[preset]

        CACHE_PRESETS[preset].dup
      end
    end

    class << self
      def current
        @current ||= new
      end

      def configure
        yield current
      end

      def reset!
        @current = new
      end
    end
  end

  def self.configuration
    Configuration.current
  end

  def self.configure(&block)
    Configuration.configure(&block)
  end

  def self.reset_configuration!
    Configuration.reset!
  end
end
