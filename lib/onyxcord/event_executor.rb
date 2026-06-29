# frozen_string_literal: true

require 'onyxcord/async/runtime'

module OnyxCord
  module EventExecutor
    STOP = Object.new.freeze

    class Inline
      def post
        yield
      end

      def shutdown; end

      def threads
        []
      end
    end

    class Pool
      attr_reader :queue

      def initialize(size:, queue_size: nil)
        raise ArgumentError, 'Pool size must be greater than zero' unless size.positive?

        @size = size
        @queue = queue_size ? SizedQueue.new(queue_size) : Queue.new
        @closed = false
        @workers = []

        start_workers
      end

      def post(&block)
        raise ArgumentError, 'EventExecutor::Pool#post requires a block' unless block
        raise 'Event executor has been shut down' if @closed

        @queue << block
      end

      def queue_size
        @queue.size
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
        rescue StandardError => e
          OnyxCord::LOGGER.log_exception(e) if defined?(OnyxCord::LOGGER)
        end
      end
    end

    class AsyncPool
      attr_reader :queue

      def initialize(size:, queue_size: nil)
        raise ArgumentError, 'Pool size must be greater than zero' unless size.positive?

        @size = size
        @queue = ::Async::Queue.new
        @closed = false
        @workers = []
        start_workers
      end

      def post(&block)
        raise ArgumentError, 'EventExecutor::AsyncPool#post requires a block' unless block
        raise 'Event executor has been shut down' if @closed

        @queue.enqueue(block)
      end

      def queue_size
        @queue.size
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
          OnyxCord::AsyncRuntime.async do
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
