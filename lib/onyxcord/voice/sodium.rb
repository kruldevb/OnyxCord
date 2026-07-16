# frozen_string_literal: true

require 'ffi'
require 'securerandom'

# :nodoc:
module OnyxCord::Voice
  # @!visibility private
  module Sodium
    extend FFI::Library
    ffi_lib 'sodium'

    # @!group Constants

    # Initializes libsodium
    # @return [Integer] 0 on success
    attach_function :sodium_init, [], :int

    # Returns the key size (in bytes)
    # @return [Integer]
    attach_function :crypto_aead_xchacha20poly1305_ietf_keybytes, [], :size_t

    # Returns the nonce size (in bytes)
    # @return [Integer]
    attach_function :crypto_aead_xchacha20poly1305_ietf_npubbytes, [], :size_t

    # Returns the authentication tag size (in bytes)
    # @return [Integer]
    attach_function :crypto_aead_xchacha20poly1305_ietf_abytes, [], :size_t

    # @!endgroup

    # @!group AEAD Encrypt/Decrypt

    # Performs authenticated encryption using XChaCha20-Poly1305
    #
    # @!macro [attach] crypto_aead_xchacha20poly1305_ietf_encrypt
    # @param c [FFI::Pointer] output buffer for ciphertext
    # @param clen_p [FFI::Pointer] output pointer for ciphertext length
    # @param m [FFI::Pointer] input message pointer
    # @param mlen [Integer] length of the message
    # @param ad [FFI::Pointer] pointer to associated data
    # @param adlen [Integer] length of associated data
    # @param nsec [FFI::Pointer, nil] (not used, must be nil)
    # @param npub [FFI::Pointer] nonce pointer
    # @param k [FFI::Pointer] key pointer
    # @return [Integer] 0 on success
    attach_function :crypto_aead_xchacha20poly1305_ietf_encrypt, %i[
      pointer pointer pointer ulong_long
      pointer ulong_long
      pointer pointer pointer
    ], :int

    # Decrypts XChaCha20-Poly1305 AEAD-encrypted data
    # @!macro [attach] crypto_aead_xchacha20poly1305_ietf_decrypt
    # @param m [FFI::Pointer] output buffer for decrypted message
    # @param mlen_p [FFI::Pointer] output pointer for decrypted length
    # @param nsec [FFI::Pointer, nil] (not used, must be nil)
    # @param c [FFI::Pointer] ciphertext pointer
    # @param clen [Integer] length of ciphertext
    # @param ad [FFI::Pointer] pointer to associated data
    # @param adlen [Integer] length of associated data
    # @param npub [FFI::Pointer] nonce pointer
    # @param k [FFI::Pointer] key pointer
    # @return [Integer] 0 on success
    attach_function :crypto_aead_xchacha20poly1305_ietf_decrypt, %i[
      pointer pointer pointer pointer ulong_long
      pointer ulong_long pointer pointer
    ], :int

    # @!endgroup

    # @!group AES-256-GCM Constants

    # Returns the AES-256-GCM key size (in bytes)
    # @return [Integer]
    attach_function :crypto_aead_aes256gcm_keybytes, [], :size_t

    # Returns the AES-256-GCM nonce size (in bytes)
    # @return [Integer]
    attach_function :crypto_aead_aes256gcm_npubbytes, [], :size_t

    # Returns the AES-256-GCM authentication tag size (in bytes)
    # @return [Integer]
    attach_function :crypto_aead_aes256gcm_abytes, [], :size_t

    # @!endgroup

    # @!group AES-256-GCM AEAD Encrypt/Decrypt

    # Performs authenticated encryption using AES-256-GCM
    attach_function :crypto_aead_aes256gcm_encrypt, %i[
      pointer pointer pointer ulong_long
      pointer ulong_long
      pointer pointer pointer
    ], :int

    # Decrypts AES-256-GCM AEAD-encrypted data
    attach_function :crypto_aead_aes256gcm_decrypt, %i[
      pointer pointer pointer pointer ulong_long
      pointer ulong_long pointer pointer
    ], :int

    # @!endgroup
  end

  result = Sodium.sodium_init
  raise "libsodium initialization failed (returned #{result})" if result.negative?

  # High-level wrapper class
  class XChaCha20AEAD
    KEY_BYTES = Sodium.crypto_aead_xchacha20poly1305_ietf_keybytes
    NONCE_BYTES = Sodium.crypto_aead_xchacha20poly1305_ietf_npubbytes
    TAG_BYTES = Sodium.crypto_aead_xchacha20poly1305_ietf_abytes

    # Generates a random key
    # @return [String] binary key
    def self.generate_key
      SecureRandom.random_bytes(KEY_BYTES)
    end

    # Generates a random nonce
    # @return [String] binary nonce
    def self.generate_nonce
      SecureRandom.random_bytes(NONCE_BYTES)
    end

    # Encrypts a message using XChaCha20-Poly1305
    #
    # @param message [String] plaintext to encrypt
    # @param key [String] 32-byte encryption key
    # @param nonce [String] 24-byte nonce
    # @param add [String] optional associated data
    # @return [String] ciphertext (includes the auth tag)
    def self.encrypt(message, add, nonce, key)
      raise ArgumentError, 'Invalid key size' unless key.bytesize == KEY_BYTES
      raise ArgumentError, 'Invalid nonce size' unless nonce.bytesize == NONCE_BYTES

      message_ptr = FFI::MemoryPointer.from_string(message)
      ad_ptr = FFI::MemoryPointer.from_string(add)

      c_len = message.bytesize + TAG_BYTES
      ciphertext = FFI::MemoryPointer.new(:uchar, c_len)
      clen_p = FFI::MemoryPointer.new(:ulong_long)

      result = Sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(
        ciphertext, clen_p,
        message_ptr, message.bytesize,
        ad_ptr, add.bytesize,
        nil,
        FFI::MemoryPointer.from_string(nonce),
        FFI::MemoryPointer.from_string(key)
      )

      raise 'Encryption failed' unless result.zero?

      ciphertext.read_string(clen_p.read_ulong_long)
    end

    # Maximum ciphertext size (1 MB)
    MAX_CIPHERTEXT_SIZE = 1_048_576

    # Decrypts a ciphertext using XChaCha20-Poly1305
    #
    # @param ciphertext [String] the encrypted data (with tag)
    # @param key [String] 32-byte decryption key
    # @param nonce [String] 24-byte nonce
    # @param add [String] optional associated data
    # @return [String] decrypted plaintext
    # @raise [ArgumentError] if ciphertext is too small, too large, or not a binary string
    def self.decrypt(ciphertext, add, nonce, key)
      raise ArgumentError, 'Ciphertext must be a binary string' unless ciphertext.is_a?(String) && ciphertext.encoding == Encoding::BINARY
      raise ArgumentError, "Ciphertext too small (minimum #{TAG_BYTES} bytes, got #{ciphertext.bytesize})" if ciphertext.bytesize < TAG_BYTES
      raise ArgumentError, "Ciphertext too large: #{ciphertext.bytesize} bytes" if ciphertext.bytesize > MAX_CIPHERTEXT_SIZE
      raise ArgumentError, 'Invalid key size' unless key.bytesize == KEY_BYTES
      raise ArgumentError, 'Invalid nonce size' unless nonce.bytesize == NONCE_BYTES

      c_ptr = FFI::MemoryPointer.from_string(ciphertext)
      ad_ptr = FFI::MemoryPointer.from_string(add)

      m_ptr = FFI::MemoryPointer.new(:uchar, ciphertext.bytesize - TAG_BYTES)
      mlen_p = FFI::MemoryPointer.new(:ulong_long)

      result = Sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(
        m_ptr, mlen_p,
        nil,
        c_ptr, ciphertext.bytesize,
        ad_ptr, add.bytesize,
        FFI::MemoryPointer.from_string(nonce),
        FFI::MemoryPointer.from_string(key)
      )

      raise 'Decryption failed: authentication tag mismatch' unless result.zero?

      m_ptr.read_string(mlen_p.read_ulong_long)
    end
  end

  # High-level wrapper for AES-256-GCM encryption
  class AES256GCM
    KEY_BYTES = Sodium.crypto_aead_aes256gcm_keybytes
    NONCE_BYTES = Sodium.crypto_aead_aes256gcm_npubbytes
    TAG_BYTES = Sodium.crypto_aead_aes256gcm_abytes

    # Check if AES-256-GCM is available on this hardware
    def self.available?
      Sodium.respond_to?(:crypto_aead_aes256gcm_encrypt)
    end

    # Generates a random key
    # @return [String] binary key
    def self.generate_key
      SecureRandom.random_bytes(KEY_BYTES)
    end

    # Generates a random nonce
    # @return [String] binary nonce
    def self.generate_nonce
      SecureRandom.random_bytes(NONCE_BYTES)
    end

    # Encrypts a message using AES-256-GCM
    #
    # @param message [String] plaintext to encrypt
    # @param add [String] optional associated data
    # @param nonce [String] 12-byte nonce
    # @param key [String] 32-byte encryption key
    # @return [String] ciphertext (includes the auth tag)
    def self.encrypt(message, add, nonce, key)
      raise ArgumentError, 'AES-256-GCM not available on this system' unless available?
      raise ArgumentError, "Invalid key size: expected #{KEY_BYTES}, got #{key.bytesize}" unless key.bytesize == KEY_BYTES
      raise ArgumentError, "Invalid nonce size: expected #{NONCE_BYTES}, got #{nonce.bytesize}" unless nonce.bytesize == NONCE_BYTES

      message_ptr = FFI::MemoryPointer.from_string(message)
      ad_ptr = FFI::MemoryPointer.from_string(add)

      c_len = message.bytesize + TAG_BYTES
      ciphertext = FFI::MemoryPointer.new(:uchar, c_len)
      clen_p = FFI::MemoryPointer.new(:ulong_long)

      result = Sodium.crypto_aead_aes256gcm_encrypt(
        ciphertext, clen_p,
        message_ptr, message.bytesize,
        ad_ptr, add.bytesize,
        nil,
        FFI::MemoryPointer.from_string(nonce),
        FFI::MemoryPointer.from_string(key)
      )

      raise 'AES-256-GCM encryption failed' unless result.zero?

      ciphertext.read_string(clen_p.read_ulong_long)
    end

    # Maximum ciphertext size (1 MB)
    MAX_CIPHERTEXT_SIZE = 1_048_576

    # Decrypts a ciphertext using AES-256-GCM
    #
    # @param ciphertext [String] the encrypted data (with tag)
    # @param add [String] optional associated data
    # @param nonce [String] 12-byte nonce
    # @param key [String] 32-byte decryption key
    # @return [String] decrypted plaintext
    # @raise [ArgumentError] if ciphertext is too small, too large, or not a binary string
    def self.decrypt(ciphertext, add, nonce, key)
      raise ArgumentError, 'AES-256-GCM not available on this system' unless available?
      raise ArgumentError, 'Ciphertext must be a binary string' unless ciphertext.is_a?(String) && ciphertext.encoding == Encoding::BINARY
      raise ArgumentError, "Ciphertext too small (minimum #{TAG_BYTES} bytes, got #{ciphertext.bytesize})" if ciphertext.bytesize < TAG_BYTES
      raise ArgumentError, "Ciphertext too large: #{ciphertext.bytesize} bytes" if ciphertext.bytesize > MAX_CIPHERTEXT_SIZE
      raise ArgumentError, "Invalid key size: expected #{KEY_BYTES}, got #{key.bytesize}" unless key.bytesize == KEY_BYTES
      raise ArgumentError, "Invalid nonce size: expected #{NONCE_BYTES}, got #{nonce.bytesize}" unless nonce.bytesize == NONCE_BYTES

      c_ptr = FFI::MemoryPointer.from_string(ciphertext)
      ad_ptr = FFI::MemoryPointer.from_string(add)

      m_ptr = FFI::MemoryPointer.new(:uchar, ciphertext.bytesize - TAG_BYTES)
      mlen_p = FFI::MemoryPointer.new(:ulong_long)

      result = Sodium.crypto_aead_aes256gcm_decrypt(
        m_ptr, mlen_p,
        nil,
        c_ptr, ciphertext.bytesize,
        ad_ptr, add.bytesize,
        FFI::MemoryPointer.from_string(nonce),
        FFI::MemoryPointer.from_string(key)
      )

      raise 'AES-256-GCM decryption failed: authentication tag mismatch' unless result.zero?

      m_ptr.read_string(mlen_p.read_ulong_long)
    end
  end
end
