# frozen_string_literal: true

if RUBY_PLATFORM.match?(/mswin|mingw|windows/)

  # @!visibility private
  module OnyxCord::Voice::WinTimer
    extend FFI::Library

    ffi_lib 'winmm'

    attach_function :time_begin_period, :timeBeginPeriod, [:uint], :uint

    attach_function :time_end_period, :timeEndPeriod, [:uint], :uint

    TIMER_RESOLUTION = 1

    class << self
      # Activate high-resolution timer. Reference-counted: safe to call multiple times.
      def activate
        @mutex ||= Mutex.new
        @refcount ||= 0

        @mutex.synchronize do
          @refcount += 1
          if @refcount == 1
            result = time_begin_period(TIMER_RESOLUTION)
            @active = result == 0
          end
        end
      end

      # Deactivate high-resolution timer. Decrements refcount; only calls timeEndPeriod when last user releases.
      def deactivate
        @mutex ||= Mutex.new
        @refcount ||= 0

        @mutex.synchronize do
          @refcount = [@refcount - 1, 0].max
          if @refcount.zero? && @active
            time_end_period(TIMER_RESOLUTION)
            @active = false
          end
        end
      end
    end
  end
end
