# frozen_string_literal: true

# Voice networking — uses OnyxCord::Internal::WebSocket (async-websocket based)
require 'socket'
require_relative '../internal/json'
require_relative '../internal/websocket'
require 'onyxcord/voice/opcodes'

begin
  LIBSODIUM_AVAILABLE = if ENV['ONYXCORD_NONACL']
                          false
                        else
                          require 'onyxcord/voice/sodium'
                        end
rescue LoadError
  puts "libsodium not available! You can continue to use onyxcord as normal but voice support won't work.
        Read https://github.com/kruldevb/OnyxCord/wiki/Installing-libsodium for more details."
  LIBSODIUM_AVAILABLE = false
end

module OnyxCord::Voice
  # Signifies to Discord that encryption should be used
  # @deprecated Discord now supports multiple encryption options.
  # TODO: Resolve replacement for this constant.
  ENCRYPTED_MODE = 'aead_xchacha20_poly1305_rtpsize'

  # Signifies to Discord that no encryption should be used
  # @deprecated Discord no longer supports unencrypted voice communication.
  PLAIN_MODE = 'plain'

  # Encryption modes supported by Discord
  ENCRYPTION_MODES = %w[aead_xchacha20_poly1305_rtpsize].freeze

  require 'onyxcord/voice/network/udp'
  require 'onyxcord/voice/network/websocket'
end
