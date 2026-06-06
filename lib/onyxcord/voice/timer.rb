# frozen_string_literal: true

if RUBY_PLATFORM.match?(/mswin|mingw|windows/)

  # @!visibility private
  module OnyxCord::Voice::WinTimer
    extend FFI::Library

    ffi_lib 'winmm'

    attach_function :time_begin_period, :timeBeginPeriod, [:uint], :uint

    attach_function :time_end_period, :timeEndPeriod, [:uint], :uint
  end

  OnyxCord::Voice::WinTimer.time_begin_period(1)

  at_exit { OnyxCord::Voice::WinTimer.time_end_period(1) }
end
