# frozen_string_literal: true

require 'async'

module OnyxCord
  module AsyncRuntime
    module_function

    def run(&block)
      current = Async::Task.current?
      return yield current if current

      Async(&block).wait
    end

    def async(&block)
      current = Async::Task.current?
      return current.async(&block) if current

      Async(&block)
    end

    def sleep(duration)
      task = Async::Task.current?
      return task.sleep(duration) if task.respond_to?(:sleep)

      Kernel.sleep(duration)
    end
  end
end