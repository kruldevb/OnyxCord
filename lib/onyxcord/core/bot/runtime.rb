# frozen_string_literal: true

module OnyxCord
  class Bot
    module Runtime
      # Runs the bot, which logs into Discord and connects the WebSocket. This
      # prevents all further execution unless it is executed with
      # `background` = `true`.
      # @param background [true, false] If it is `true`, then the bot will run in
      #   another thread to allow further execution. If it is `false`, this method
      #   will block until {#stop} is called. If the bot is run with `true`, make
      #   sure to eventually call {#join} so the script doesn't stop prematurely.
      # @note Running the bot in the background means that you can call some
      #   methods that require a gateway connection *before* that connection is
      #   established. In most cases an exception will be raised if you try to do
      #   this. If you need a way to safely run code after the bot is fully
      #   connected, use a {#ready} event handler instead.
      def run(background = false)
        if background
          @run_task = Internal::AsyncRuntime.async { run_forever }
          return @run_task
        end

        Internal::AsyncRuntime.run { run_forever }
      end

      def run_forever
        @gateway.run
      end

      def join
        @run_task&.wait
      end
      alias_method :sync, :join

      def stop(_no_sync = nil)
        @gateway.stop
        @event_executor.shutdown
        @run_task&.stop if @run_task.respond_to?(:stop)
        nil
      end

      # @return [true, false] whether or not the bot is currently connected to Discord.
      def connected?
        @gateway.open?
      end

      # Sets debug mode. If debug mode is on, many things will be outputted to STDOUT.
      def debug=(new_debug)
        LOGGER.debug = new_debug
      end

      # Sets the logging mode
      # @see Logger#mode=
      def mode=(new_mode)
        LOGGER.mode = new_mode
      end

      def runtime_stats
        {
          mode: @mode,
          cache: cache_stats,
          event_executor: @event_executor.class.name,
          event_threads: @event_threads&.count(&:alive?) || 0,
          event_queue_size: @event_executor.respond_to?(:queue_size) ? @event_executor.queue_size : 0
        }
      end

      # Prevents the READY packet from being printed regardless of debug mode.
      def suppress_ready_debug
        @prevent_ready = true
      end

      private

      # Throws a useful exception if there's currently no gateway connection.
      def gateway_check
        raise "A gateway connection is necessary to call this method! You'll have to do it inside any event (e.g. `ready`) or after `bot.run :async`." unless connected?
      end

      # Logs a warning if there are servers which are still unavailable.
      # e.g. due to a Discord outage or because the servers are large and taking a while to load.
      def unavailable_servers_check
        # Return unless there are servers that are unavailable.
        return unless @unavailable_servers&.positive?

        LOGGER.warn("#{@unavailable_servers} servers haven't been cached yet.")
        LOGGER.warn('Servers may be unavailable due to an outage, or your bot is on very large servers that are taking a while to load.')
      end

      def process_token(type, token)
        # Remove the "Bot " prefix if it exists
        token = token[4..] if token.start_with? 'Bot '

        token = "Bot #{token}" unless type == :user
        token
      end

      # Notifies everything there is to be notified that the connection is now ready
      def notify_ready
        if @mode == :raw
          notify_raw_ready
          return
        end

        # Make sure to raise the event
        raise_event(OnyxCord::Events::ReadyEvent.new(self))
        LOGGER.good 'Ready'

        @gateway.notify_ready
      end

      def raise_event(event)
        debug("Raised a #{event.class}")
        handle_awaits(event)

        @event_handlers ||= {}
        handlers = @event_handlers[event.class]
        return unless handlers

        handlers.dup.each do |handler|
          call_event(handler, event) if handler.matches?(event)
        end
      end

      def call_event(handler, event)
        @event_executor.post do
          Thread.current[:onyxcord_name] = next_event_thread_name('et')
          begin
            handler.call(event)
            handler.after_call(event)
          rescue StandardError => e
            log_exception(e)
          end
        end
      end

      def handle_awaits(event)
        @awaits ||= {}
        @awaits.each_value do |await|
          key, should_delete = await.match(event)
          next unless key

          debug("should_delete: #{should_delete}")
          @awaits.delete(await.key) if should_delete

          await_event = OnyxCord::Events::AwaitEvent.new(await, event, self)
          raise_event(await_event)
        end
      end

      def calculate_intents(intents)
        intents = [intents] unless intents.is_a? Array

        intents.reduce(0) do |sum, intent|
          case intent
          when Symbol
            intent = INTENT_ALIASES[intent] || intent

            if INTENTS[intent]
              sum | INTENTS[intent]
            else
              LOGGER.warn("Unknown intent: #{intent}")
              sum
            end
          when Integer
            sum | intent
          else
            LOGGER.warn("Invalid intent: #{intent}")
            sum
          end
        end
      end

      def next_event_thread_name(prefix)
        @current_thread_mutex.synchronize do
          @current_thread += 1
          "#{prefix}-#{@current_thread}"
        end
      end
    end
  end
end
