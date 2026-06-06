# frozen_string_literal: true

require 'onyxcord/voice/sodium'

describe OnyxCord::Voice::Sodium do
  def rand_bytes(size)
    bytes = Array.new(size) { rand(256) }
    bytes.pack('C*')
  end

  describe OnyxCord::Voice::XChaCha20AEAD do
    it 'encrypts round trip' do
      key = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::KEY_BYTES)
      nonce = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::NONCE_BYTES)
      message = rand_bytes(20)

      ct = OnyxCord::Voice::XChaCha20AEAD.encrypt(message, '', nonce, key)
      pt = OnyxCord::Voice::XChaCha20AEAD.decrypt(ct, '', nonce, key)
      expect(pt).to eq message
    end

    describe '#decrypt' do
      it 'raises on invalid nonce length' do
        rand_bytes(OnyxCord::Voice::XChaCha20AEAD::KEY_BYTES)
        nonce = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::NONCE_BYTES - 1)
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(nonce, '') }.to raise_error(ArgumentError)
      end
    end
  end
end
