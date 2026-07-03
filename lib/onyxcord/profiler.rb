# frozen_string_literal: true

require 'OnyxProfiler'
require 'yaml'

module OnyxCord
  # OnyxProfiler integration for observability and profiling
  module Profiler
    class << self
      attr_reader :configured, :config_path

      def load_config_file(path = nil)
        @config_path = path || File.join(Dir.pwd, 'onyxprofiler.config')
        return unless File.exist?(@config_path)

        YAML.load_file(@config_path)
      rescue StandardError => e
        warn "Failed to load OnyxProfiler config: #{e.message}"
        {}
      end

      def configure
        return if @configured

        config_data = load_config_file

        OnyxProfiler.configure do |config|
          config.enabled = ENV.fetch('ONYX_PROFILER_ENABLED', config_data['enabled'] || true)
          config.project = ENV.fetch('ONYX_PROFILER_PROJECT', config_data['project'] || 'onyxcord')
          config.service = ENV.fetch('ONYX_PROFILER_SERVICE', config_data['service'] || 'gateway')
          config.environment = ENV.fetch('ONYX_PROFILER_ENVIRONMENT', config_data['environment'] || ENV.fetch('ONYX_ENV', 'production'))
          config.dashboard_url = ENV.fetch('ONYX_PROFILER_DASHBOARD_URL', config_data['dashboard_url'] || 'http://localhost:3000')
          config.api_key = ENV.fetch('ONYX_PROFILER_API_KEY', config_data['api_key'] || 'onyx_pk_5a7d8e36516948e0b26728d651f5c066')
          config.batch_size = ENV.fetch('ONYX_PROFILER_BATCH_SIZE', config_data['batch_size'] || 25).to_i
          config.buffer_size = ENV.fetch('ONYX_PROFILER_BUFFER_SIZE', config_data['buffer_size'] || 500).to_i

          config.exporter = OnyxProfiler::Exporters::Dashboard.new(
            config.dashboard_url,
            api_key: config.api_key,
            batch_size: config.batch_size
          )
        end

        @configured = true
      end

      def instrument(name, **metadata, &block)
        configure unless @configured
        OnyxProfiler.instrument(name, **metadata, &block)
      end

      def flush_to
        OnyxProfiler.flush_to
      end

      def flush
        OnyxProfiler.flush
      end

      def auto_instrument_gateway!
        return unless @configured

        # Auto-instrument gateway events
        OnyxProfiler::Integrations::OnyxCord.install if defined?(OnyxProfiler::Integrations::OnyxCord)
      end
    end
  end
end
