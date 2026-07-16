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
  warn "onyxcord: libsodium not available — voice support disabled. See https://github.com/kruldevb/OnyxCord/wiki/Installing-libsodium"
  LIBSODIUM_AVAILABLE = false
rescue RuntimeError => e
  warn "onyxcord: libsodium initialization failed — voice support disabled: #{e.message}"
  LIBSODIUM_AVAILABLE = false
end

# Returns whether voice support is available (libsodium loaded and initialized)
def self.voice_available?
  LIBSODIUM_AVAILABLE == true
end

module OnyxCord::Voice
  # Signifies to Discord that encryption should be used
  # @deprecated Discord now supports multiple encryption options.
  # TODO: Resolve replacement for this constant.
  ENCRYPTED_MODE = 'aead_xchacha20_poly1305_rtpsize'

  # Signifies to Discord that no encryption should be used
  # @deprecated Discord no longer supports unencrypted voice communication.
  PLAIN_MODE = 'plain'

  # Encryption modes supported by Discord (XChaCha20 preferred, AES-256-GCM as fallback)
  ENCRYPTION_MODES = %w[aead_xchacha20_poly1305_rtpsize aead_aes256gcm_rtpsize].freeze

  require 'onyxcord/voice/network/udp'
  require 'onyxcord/voice/network/websocket'
end
