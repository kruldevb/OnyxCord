# frozen_string_literal: true

require_relative 'async_runtime'

module OnyxCord
  module Internal
    module EventExecutor
      STOP = Object.new.freeze

      REPLACEABLE_EVENTS = %i[typing_start presence_update voice_state_update].freeze

      class Inline
        def post(_event_type = nil)
          yield
        end

        def shutdown; end

        def threads
          []
        end

        def discarded_count
          0
        end
      end

      class Pool
        attr_reader :queue

        def initialize(size:, queue_size: nil)
          raise ArgumentError, 'Pool size must be greater than zero' unless size.positive?

          @size = size
          @queue = queue_size ? SizedQueue.new(queue_size) : Queue.new
          @replaceable = {}
          @replaceable_mutex = Mutex.new
          @discarded_mutex = Mutex.new
          @discarded = 0
          @closed = false
          @workers = []

          start_workers
        end

        def post(event_type = nil, &block)
          raise ArgumentError, 'EventExecutor::Pool#post requires a block' unless block
          raise 'Event executor has been shut down' if @closed

          if event_type && REPLACEABLE_EVENTS.include?(event_type)
            @replaceable_mutex.synchronize do
              @replaceable[event_type] = block
            end
            return
          end

          @queue.push(block)
        rescue ThreadError
          @discarded_mutex.synchronize { @discarded += 1 }
          OnyxCord::LOGGER.debug('Event queue full, dropping event') if defined?(OnyxCord::LOGGER)
        end

        def queue_size
          @queue.size
        end

        def discarded_count
          @discarded_mutex.synchronize { @discarded }
        end

        def threads
          @workers
        end

        def shutdown
          return if @closed

          @closed = true
          @size.times { @queue << STOP }
          @workers.each do |w|
            w.join unless w == Thread.current
          rescue StandardError
            nil
          end
        end

        private

        def start_workers
          @workers = Array.new(@size) do |index|
            Thread.new do
              Thread.current[:onyxcord_name] = "event-worker-#{index + 1}"
              worker_loop
            end
          end
        end

        def worker_loop
          loop do
            job = @queue.pop
            break if job.equal?(STOP)

            job.call
            drain_replaceable
          rescue StandardError => e
            OnyxCord::LOGGER.log_exception(e) if defined?(OnyxCord::LOGGER)
          end
        end

        def drain_replaceable
          @replaceable_mutex.synchronize do
            @replaceable.each_value(&:call)
            @replaceable.clear
          end
        end
      end

      class AsyncPool
        attr_reader :queue

        def initialize(size:, queue_size: nil) # rubocop:disable Lint/UnusedMethodArgument
          raise ArgumentError, 'Pool size must be greater than zero' unless size.positive?

          @size = size
          @queue = ::Async::Queue.new
          @replaceable = {}
          @replaceable_mutex = Mutex.new
          @discarded_mutex = Mutex.new
          @discarded = 0
          @closed = false
          @workers = []
          start_workers
        end

        def post(event_type = nil, &block)
          raise ArgumentError, 'EventExecutor::AsyncPool#post requires a block' unless block
          raise 'Event executor has been shut down' if @closed

          if event_type && REPLACEABLE_EVENTS.include?(event_type)
            @replaceable_mutex.synchronize do
              @replaceable[event_type] = block
            end
            return
          end

          @queue.enqueue(block)
        rescue ThreadError
          @discarded_mutex.synchronize { @discarded += 1 }
        end

        def queue_size
          @queue.size
        end

        def discarded_count
          @discarded_mutex.synchronize { @discarded }
        end

        def shutdown
          return if @closed

          @closed = true
          @size.times { @queue.enqueue(STOP) }
        end

        def threads
          []
        end

        private

        def start_workers
          @workers = Array.new(@size) do
            AsyncRuntime.async do
              loop do
                job = @queue.dequeue
                break if job.equal?(STOP)

                job.call
              rescue StandardError => e
                OnyxCord::LOGGER.log_exception(e) if defined?(OnyxCord::LOGGER)
              end
            end
          end
        end
      end

      module_function

      def build(type, workers:, queue_size: nil)
        case type
        when :inline
          Inline.new
        when :pool
          Pool.new(size: workers, queue_size: queue_size)
        when :async_pool
          AsyncPool.new(size: workers, queue_size: queue_size)
        else
          raise ArgumentError, "Unknown event executor: #{type.inspect}"
        end
      end
    end
  end
end
