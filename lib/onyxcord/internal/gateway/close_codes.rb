# frozen_string_literal: true

module OnyxCord
  module Internal
    module Gateway
      CloseCode = Struct.new(:code, :reconnect?, :resume?, :invalidate?, :fatal?, keyword_init: true)

      CLOSE_CODES = {
        4000 => CloseCode.new(code: 4000, reconnect?: true,  resume?: true,  invalidate?: false, fatal?: false),
        4001 => CloseCode.new(code: 4001, reconnect?: true,  resume?: true,  invalidate?: false, fatal?: false),
        4002 => CloseCode.new(code: 4002, reconnect?: true,  resume?: true,  invalidate?: false, fatal?: false),
        4003 => CloseCode.new(code: 4003, reconnect?: true,  resume?: false, invalidate?: true,  fatal?: false),
        4004 => CloseCode.new(code: 4004, reconnect?: false, resume?: false, invalidate?: true,  fatal?: true),
        4005 => CloseCode.new(code: 4005, reconnect?: true,  resume?: true,  invalidate?: false, fatal?: false),
        4006 => CloseCode.new(code: 4006, reconnect?: true,  resume?: false, invalidate?: true,  fatal?: false),
        4007 => CloseCode.new(code: 4007, reconnect?: true,  resume?: false, invalidate?: true,  fatal?: false),
        4008 => CloseCode.new(code: 4008, reconnect?: true,  resume?: true,  invalidate?: false, fatal?: false),
        4009 => CloseCode.new(code: 4009, reconnect?: true,  resume?: false, invalidate?: true,  fatal?: false),
        4010 => CloseCode.new(code: 4010, reconnect?: false, resume?: false, invalidate?: true,  fatal?: true),
        4011 => CloseCode.new(code: 4011, reconnect?: false, resume?: false, invalidate?: true,  fatal?: true),
        4012 => CloseCode.new(code: 4012, reconnect?: false, resume?: false, invalidate?: true,  fatal?: true),
        4013 => CloseCode.new(code: 4013, reconnect?: false, resume?: false, invalidate?: true,  fatal?: true),
        4014 => CloseCode.new(code: 4014, reconnect?: false, resume?: false, invalidate?: true,  fatal?: true)
      }.freeze

      def self.close_info(code)
        CLOSE_CODES.fetch(code, CloseCode.new(code: code, reconnect?: true, resume?: false, invalidate?: false, fatal?: false))
      end
    end
  end
end
