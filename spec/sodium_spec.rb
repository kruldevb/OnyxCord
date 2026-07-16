# frozen_string_literal: true

require 'onyxcord/voice/sodium'
require 'onyxcord/voice/network'

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
      let(:key) { rand_bytes(OnyxCord::Voice::XChaCha20AEAD::KEY_BYTES) }
      let(:nonce) { rand_bytes(OnyxCord::Voice::XChaCha20AEAD::NONCE_BYTES) }
      let(:message) { rand_bytes(20) }
      let(:ciphertext) { OnyxCord::Voice::XChaCha20AEAD.encrypt(message, '', nonce, key) }

      it 'raises on invalid nonce length' do
        short_nonce = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::NONCE_BYTES - 1)
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(ciphertext, '', short_nonce, key) }.to raise_error(ArgumentError, /Invalid nonce size/)
      end

      it 'raises on invalid key length' do
        short_key = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::KEY_BYTES - 1)
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(ciphertext, '', nonce, short_key) }.to raise_error(ArgumentError, /Invalid key size/)
      end

      it 'raises on corrupted authentication tag' do
        # Flip a bit in the last byte (part of the tag)
        corrupted = ciphertext.dup
        corrupted[-1] = (corrupted[-1].ord ^ 0xFF).chr
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(corrupted, '', nonce, key) }.to raise_error(RuntimeError, /Decryption failed/)
      end

      it 'raises on too-short ciphertext' do
        short_ct = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::TAG_BYTES - 1)
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(short_ct, '', nonce, key) }.to raise_error(ArgumentError, /too small/)
      end

      it 'raises on non-binary ciphertext' do
        utf8_ct = 'not binary'
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(utf8_ct, '', nonce, key) }.to raise_error(ArgumentError, /binary string/)
      end

      it 'decrypts with associated data' do
        aad = 'some associated data'
        ct = OnyxCord::Voice::XChaCha20AEAD.encrypt(message, aad, nonce, key)
        pt = OnyxCord::Voice::XChaCha20AEAD.decrypt(ct, aad, nonce, key)
        expect(pt).to eq message
      end

      it 'fails to decrypt with wrong associated data' do
        ct = OnyxCord::Voice::XChaCha20AEAD.encrypt(message, 'correct aad', nonce, key)
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(ct, 'wrong aad', nonce, key) }.to raise_error(RuntimeError, /Decryption failed/)
      end
    end
  end
end

describe OnyxCord::Voice::VoiceUDP do
  it 'closes the UDP socket and clears secret key' do
    udp = described_class.allocate
    socket = instance_double(UDPSocket, closed?: false, close: nil)
    udp.instance_variable_set(:@socket, socket)
    udp.instance_variable_set(:@secret_key, 'super-secret-key')

    udp.close

    expect(socket).to have_received(:close)
    expect(udp.instance_variable_get(:@secret_key)).to be_nil
  end

  it 'redacts secret_key in inspect' do
    udp = described_class.new
    udp.instance_variable_set(:@secret_key, 'super-secret-key')
    expect(udp.inspect).not_to include('super-secret-key')
    expect(udp.inspect).to include('[REDACTED]')
  end
end

describe OnyxCord::Voice::VoiceWS do
  it 'closes websocket, udp, and joins its owner thread on destroy' do
    ws = described_class.allocate
    client = instance_double(OnyxCord::Internal::WebSocket, close: nil)
    udp = instance_double(OnyxCord::Voice::VoiceUDP, close: nil)
    thread = instance_double(Thread, join: nil, alive?: false)

    ws.instance_variable_set(:@client, client)
    ws.instance_variable_set(:@udp, udp)
    ws.instance_variable_set(:@thread, thread)

    ws.destroy(0.01)

    expect(client).to have_received(:close)
    expect(udp).to have_received(:close)
    expect(thread).to have_received(:join).with(0.01)
  end

  describe '#send_speaking' do
    it 'normalizes boolean to bitmask' do
      ws = described_class.allocate
      ws.instance_variable_set(:@ready, true)
      ws.instance_variable_set(:@ssrc, 12345)
      ws.instance_variable_set(:@bot, double(debug: nil))
      ws.instance_variable_set(:@client, double(send: nil))

      expect(ws).to receive(:send_opcode).with(5, { speaking: 1, delay: 0, ssrc: 12345 })
      ws.send_speaking(true)

      expect(ws).to receive(:send_opcode).with(5, { speaking: 0, delay: 0, ssrc: 12345 })
      ws.send_speaking(false)
    end

    it 'raises if not ready' do
      ws = described_class.allocate
      ws.instance_variable_set(:@ready, false)

      expect { ws.send_speaking(true) }.to raise_error(RuntimeError, /not ready/)
    end
  end

  describe '#send_init' do
    it 'stores server_id and bot_user_id' do
      ws = described_class.allocate
      ws.instance_variable_set(:@client, double(send: nil))
      ws.instance_variable_set(:@bot, double(debug: nil))

      ws.send_init(111, 222, 'session', 'token')

      expect(ws.instance_variable_get(:@server_id)).to eq(111)
      expect(ws.instance_variable_get(:@bot_user_id)).to eq(222)
    end
  end
end
