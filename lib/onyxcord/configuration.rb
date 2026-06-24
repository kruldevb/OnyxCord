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
        server_previews: false,
        members: false,
        messages: false
      },
      minimal: {
        users: false,
        voice_regions: false,
        servers: true,
        channels: true,
        pm_channels: false,
        thread_members: false,
        server_previews: false,
        members: false,
        messages: false
      },
      full: {
        users: true,
        voice_regions: true,
        servers: true,
        channels: true,
        pm_channels: true,
        thread_members: true,
        server_previews: true,
        members: true,
        messages: true
      }
    }.freeze

    attr_accessor :mode, :cache, :event_executor, :event_workers, :event_queue_size

    def initialize
      @mode = :hybrid
      @cache = :none
      @event_executor = :pool
      @event_workers = 4
      @event_queue_size = nil
    end

    def dup
      copy = self.class.new
      copy.mode = @mode
      copy.cache = @cache.is_a?(Hash) ? @cache.dup : @cache
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
        CACHE_PRESETS[:none].merge(cache.transform_keys(&:to_sym))
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
