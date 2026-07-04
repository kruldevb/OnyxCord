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
      it 'raises on invalid nonce length' do
        rand_bytes(OnyxCord::Voice::XChaCha20AEAD::KEY_BYTES)
        nonce = rand_bytes(OnyxCord::Voice::XChaCha20AEAD::NONCE_BYTES - 1)
        expect { OnyxCord::Voice::XChaCha20AEAD.decrypt(nonce, '') }.to raise_error(ArgumentError)
      end
    end
  end
end

describe OnyxCord::Voice::VoiceUDP do
  it 'closes the UDP socket' do
    udp = described_class.allocate
    socket = instance_double(UDPSocket, closed?: false, close: nil)
    udp.instance_variable_set(:@socket, socket)

    udp.close

    expect(socket).to have_received(:close)
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
end
