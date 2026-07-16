# frozen_string_literal: true

require 'spec_helper'
require 'onyxcord/voice/client'
require 'onyxcord/voice/encoder'
require 'onyxcord/voice/network'
require 'onyxcord/voice/opcodes'

# Mock the WebSocket and UDP dependencies for unit testing
module OnyxCord::Voice
  # Minimal mock for testing Client without real connections
  class MockVoiceWS
    attr_reader :udp, :ssrc, :ready
    attr_accessor :sent_opcodes

    def initialize
      @udp = MockVoiceUDP.new
      @ssrc = 12345
      @ready = true
      @sent_opcodes = []
    end

    def connect; end
    def destroy; end

    def send_speaking(value)
      @sent_opcodes << [:speaking, value]
    end

    def send_init(*args); end
  end

  class MockVoiceUDP
    attr_accessor :secret_key, :mode

    def send_audio(*args); end
    def close; end
  end
end

describe OnyxCord::Voice::Client do
  let(:channel) { double('channel', server: double('server', id: 111)) }
  let(:bot) do
    double('bot',
           logger: double('logger', debug: nil, warn: nil, error: nil, log_exception: nil),
           profile: double('profile', id: 222),
           debug: nil)
  end
  let(:voice_ws) { OnyxCord::Voice::MockVoiceWS.new }

  before do
    allow(OnyxCord::Voice::VoiceWS).to receive(:new).and_return(voice_ws)
    allow(OnyxCord::Voice::Encoder).to receive(:new).and_return(
      instance_double(OnyxCord::Voice::Encoder,
                      filter_volume: 1,
                      filter_volume=: nil,
                      encode: '',
                      bitrate=: nil,
                      last_ffmpeg_error: nil,
                      last_ffmpeg_status: nil)
    )
  end

  subject(:client) { described_class.new(channel, bot, 'token', 'session', 'endpoint:443') }

  describe '#initialize' do
    it 'creates encoder before websocket' do
      expect(OnyxCord::Voice::Encoder).to receive(:new).ordered
      expect(OnyxCord::Voice::VoiceWS).to receive(:new).ordered
      described_class.new(channel, bot, 'token', 'session', 'endpoint:443')
    end

    it 'cleans up websocket on encoder failure' do
      allow(OnyxCord::Voice::Encoder).to receive(:new).and_raise(LoadError, 'opus missing')
      expect(voice_ws).to receive(:destroy)
      expect { described_class.new(channel, bot, 'token', 'session', 'endpoint:443') }.to raise_error(LoadError)
    end
  end

  describe '#volume=' do
    it 'accepts valid volume' do
      client.volume = 0.5
      expect(client.volume).to eq(0.5)
    end

    it 'rejects negative volume' do
      expect { client.volume = -1 }.to raise_error(ArgumentError, /non-negative/)
    end

    it 'rejects NaN' do
      expect { client.volume = Float::NAN }.to raise_error(ArgumentError, /NaN/)
    end

    it 'rejects Infinity' do
      expect { client.volume = Float::INFINITY }.to raise_error(ArgumentError, /Infinity/)
    end

    it 'rejects non-numeric' do
      expect { client.volume = 'loud' }.to raise_error(ArgumentError, /numeric/)
    end
  end

  describe '#speaking=' do
    it 'delegates to websocket' do
      expect(voice_ws).to receive(:send_speaking).with(true)
      client.speaking = true
    end
  end

  describe '#playing?' do
    it 'returns false initially' do
      expect(client.playing?).to be false
    end
  end

  describe '#skip' do
    it 'accumulates skip frames' do
      client.skip(0.1)
      expect(client.instance_variable_get(:@skips)).to eq(5)
    end
  end

  describe '#encrypted?' do
    it 'returns true' do
      expect(client.encrypted?).to be true
    end
  end

  describe '#destroy' do
    it 'stops playing and destroys websocket' do
      expect(voice_ws).to receive(:destroy)
      client.destroy
    end
  end
end

describe OnyxCord::Voice::Encoder do
  describe '#initialize' do
    it 'raises if opus is unavailable' do
      allow(OnyxCord::Voice).to receive(:const_get).with(:OPUS_AVAILABLE).and_return(false)
      expect { described_class.new }.to raise_error(LoadError)
    end
  end

  describe '#bitrate=' do
    subject(:encoder) { described_class.new }

    it 'accepts valid bitrate' do
      expect { encoder.bitrate = 64_000 }.not_to raise_error
    end

    it 'rejects zero' do
      expect { encoder.bitrate = 0 }.to raise_error(ArgumentError, /positive/)
    end

    it 'rejects negative' do
      expect { encoder.bitrate = -1000 }.to raise_error(ArgumentError, /positive/)
    end

    it 'rejects too low' do
      expect { encoder.bitrate = 100 }.to raise_error(ArgumentError, /range/)
    end

    it 'rejects too high' do
      expect { encoder.bitrate = 1_000_000 }.to raise_error(ArgumentError, /range/)
    end

    it 'rejects NaN' do
      expect { encoder.bitrate = Float::NAN }.to raise_error(ArgumentError, /NaN/)
    end
  end

  describe '#encode' do
    subject(:encoder) { described_class.new }

    it 'raises on wrong buffer size' do
      expect { encoder.encode('short') }.to raise_error(ArgumentError, /3840 bytes/)
    end
  end

  describe '#ffmpeg_command' do
    subject(:encoder) { described_class.new }

    it 'returns array with correct structure' do
      cmd = encoder.send(:ffmpeg_command, input: 'test.mp3')
      expect(cmd).to be_an(Array)
      expect(cmd[0]).to eq('ffmpeg')
      expect(cmd).to include('-i', 'test.mp3')
      expect(cmd).to include('-f', 's16le', '-ar', '48000', '-ac', '2', 'pipe:1')
    end

    it 'places options before output' do
      cmd = encoder.send(:ffmpeg_command, input: 'test.mp3', options: ['-af', 'volume=2'])
      output_idx = cmd.index('pipe:1')
      af_idx = cmd.index('-af')
      expect(af_idx).to be < output_idx
    end

    it 'handles nil options' do
      cmd = encoder.send(:ffmpeg_command, input: 'test.mp3', options: nil)
      expect(cmd).not_to include(nil)
    end

    it 'handles array options' do
      cmd = encoder.send(:ffmpeg_command, input: 'test.mp3', options: ['-ss', '10'])
      expect(cmd).to include('-ss', '10')
    end
  end
end

describe OnyxCord::Voice::VoiceUDP do
  describe '#close' do
    it 'clears secret key' do
      udp = described_class.new
      udp.secret_key = 'secret'
      udp.close
      expect(udp.instance_variable_get(:@secret_key)).to be_nil
    end
  end

  describe '#inspect' do
    it 'redacts secret key' do
      udp = described_class.new
      udp.secret_key = 'super-secret'
      expect(udp.inspect).not_to include('super-secret')
      expect(udp.inspect).to include('[REDACTED]')
    end
  end

  describe '#receive_discovery_reply' do
    it 'validates packet type' do
      udp = described_class.new
      socket = instance_double(UDPSocket)
      udp.instance_variable_set(:@socket, socket)
      udp.instance_variable_set(:@ssrc, 12345)

      # Build invalid packet (wrong type)
      packet = [0x1, 70, 12345].pack('nnN') + ("\0" * 66)
      allow(socket).to receive(:recvfrom).and_return([packet, ['127.0.0.1', 5000]])

      expect { udp.receive_discovery_reply }.to raise_error(RuntimeError, /unexpected type/)
    end

    it 'validates SSRC match' do
      udp = described_class.new
      socket = instance_double(UDPSocket)
      udp.instance_variable_set(:@socket, socket)
      udp.instance_variable_set(:@ssrc, 12345)

      # Build packet with wrong SSRC
      packet = [0x2, 70, 99999].pack('nnN') + ("\0" * 66)
      allow(socket).to receive(:recvfrom).and_return([packet, ['127.0.0.1', 5000]])

      expect { udp.receive_discovery_reply }.to raise_error(RuntimeError, /SSRC mismatch/)
    end

    it 'validates packet size' do
      udp = described_class.new
      socket = instance_double(UDPSocket)
      udp.instance_variable_set(:@socket, socket)

      allow(socket).to receive(:recvfrom).and_return(["\x00" * 10, ['127.0.0.1', 5000]])

      expect { udp.receive_discovery_reply }.to raise_error(RuntimeError, /too short/)
    end
  end
end

describe OnyxCord::Voice::VoiceWS do
  describe '#validate_endpoint' do
    subject(:ws) { described_class.allocate }

    it 'rejects nil endpoint' do
      expect { ws.send(:validate_endpoint, nil) }.to raise_error(ArgumentError, /nil or empty/)
    end

    it 'rejects endpoint with path' do
      expect { ws.send(:validate_endpoint, 'host/path') }.to raise_error(ArgumentError, /path/)
    end

    it 'rejects endpoint with userinfo' do
      expect { ws.send(:validate_endpoint, 'user@host') }.to raise_error(ArgumentError, /userinfo/)
    end

    it 'rejects endpoint with invalid characters' do
      expect { ws.send(:validate_endpoint, 'host;rm -rf /') }.to raise_error(ArgumentError, /invalid characters/)
    end

    it 'accepts valid host:port' do
      expect(ws.send(:validate_endpoint, 'us-east1.voice.discord.gg:443')).to eq('us-east1.voice.discord.gg:443')
    end
  end

  describe '#send_speaking' do
    it 'normalizes true to 1' do
      ws = described_class.allocate
      ws.instance_variable_set(:@ready, true)
      ws.instance_variable_set(:@ssrc, 12345)
      ws.instance_variable_set(:@bot, double(debug: nil))
      ws.instance_variable_set(:@client, double(send: nil))

      expect(ws).to receive(:send_opcode).with(5, { speaking: 1, delay: 0, ssrc: 12345 })
      ws.send_speaking(true)
    end

    it 'normalizes false to 0' do
      ws = described_class.allocate
      ws.instance_variable_set(:@ready, true)
      ws.instance_variable_set(:@ssrc, 12345)
      ws.instance_variable_set(:@bot, double(debug: nil))
      ws.instance_variable_set(:@client, double(send: nil))

      expect(ws).to receive(:send_opcode).with(5, { speaking: 0, delay: 0, ssrc: 12345 })
      ws.send_speaking(false)
    end

    it 'passes integer bitmask as-is' do
      ws = described_class.allocate
      ws.instance_variable_set(:@ready, true)
      ws.instance_variable_set(:@ssrc, 12345)
      ws.instance_variable_set(:@bot, double(debug: nil))
      ws.instance_variable_set(:@client, double(send: nil))

      expect(ws).to receive(:send_opcode).with(5, { speaking: 2, delay: 0, ssrc: 12345 })
      ws.send_speaking(2)
    end
  end
end

describe 'RTP packet generation' do
  describe OnyxCord::Voice::VoiceUDP do
    describe '#generate_header' do
      subject(:udp) { described_class.new }

      it 'generates correct RTP header' do
        udp.instance_variable_set(:@ssrc, 0x12345678)
        header = udp.send(:generate_header, 1, 960)

        # First byte: version=2, padding=0, extension=0, csrc_count=0 → 0x80
        expect(header.getbyte(0)).to eq(0x80)
        # Second byte: payload type=0x78 (120), marker=0 → 0x78
        expect(header.getbyte(1)).to eq(0x78)
        # Sequence number (big-endian 16-bit)
        expect(header[2..3].unpack1('n')).to eq(1)
        # Timestamp (big-endian 32-bit)
        expect(header[4..7].unpack1('N')).to eq(960)
        # SSRC (big-endian 32-bit)
        expect(header[8..11].unpack1('N')).to eq(0x12345678)
        # Total header length: 12 bytes
        expect(header.bytesize).to eq(12)
      end
    end

    describe '#generate_nonce' do
      subject(:udp) { described_class.new }

      it 'generates 24-byte nonce with incremental counter' do
        udp.instance_variable_set(:@mode, 'aead_xchacha20_poly1305_rtpsize')

        nonce1 = udp.send(:generate_nonce)
        nonce2 = udp.send(:generate_nonce)

        expect(nonce1.bytesize).to eq(24)
        expect(nonce2.bytesize).to eq(24)

        # First 4 bytes should be the counter (big-endian)
        counter1 = nonce1[0..3].unpack1('N')
        counter2 = nonce2[0..3].unpack1('N')
        expect(counter2).to eq(counter1 + 1)
      end

      it 'wraps counter at 0xFFFFFFFF' do
        udp.instance_variable_set(:@mode, 'aead_xchacha20_poly1305_rtpsize')
        udp.instance_variable_set(:@incremental_nonce, 0xFFFFFFFF)

        nonce = udp.send(:generate_nonce)
        counter = nonce[0..3].unpack1('N')
        expect(counter).to eq(0)
      end
    end
  end
end

describe 'Packet header wrapping' do
  let(:channel) { double('channel', server: double('server', id: 111)) }
  let(:bot) do
    double('bot',
           logger: double('logger', debug: nil, warn: nil, error: nil, log_exception: nil),
           profile: double('profile', id: 222),
           debug: nil)
  end
  let(:voice_ws) { OnyxCord::Voice::MockVoiceWS.new }

  before do
    allow(OnyxCord::Voice::VoiceWS).to receive(:new).and_return(voice_ws)
    allow(OnyxCord::Voice::Encoder).to receive(:new).and_return(
      instance_double(OnyxCord::Voice::Encoder,
                      filter_volume: 1,
                      filter_volume=: nil,
                      encode: '',
                      bitrate=: nil,
                      last_ffmpeg_error: nil,
                      last_ffmpeg_status: nil)
    )
  end

  subject(:client) { OnyxCord::Voice::Client.new(channel, bot, 'token', 'session', 'endpoint:443') }

  describe '#increment_packet_headers' do
    it 'increments sequence and time correctly' do
      client.instance_variable_set(:@sequence, 0)
      client.instance_variable_set(:@time, 0)

      client.send(:increment_packet_headers)

      expect(client.instance_variable_get(:@sequence)).to eq(1)
      expect(client.instance_variable_get(:@time)).to eq(960)
    end

    it 'wraps sequence at 0xFFFF' do
      client.instance_variable_set(:@sequence, 0xFFFF)
      client.instance_variable_set(:@time, 0)

      client.send(:increment_packet_headers)

      expect(client.instance_variable_get(:@sequence)).to eq(0)
      expect(client.instance_variable_get(:@time)).to eq(960)
    end

    it 'wraps time at 0xFFFFFFFF' do
      client.instance_variable_set(:@sequence, 0)
      client.instance_variable_get(:@time, 0xFFFFFFFF - 959)

      client.send(:increment_packet_headers)

      expect(client.instance_variable_get(:@sequence)).to eq(1)
      expect(client.instance_variable_get(:@time)).to eq(0)
    end

    it 'does not reset counters prematurely' do
      # At sequence 0xFFFE, increment should go to 0xFFFF, not 0
      client.instance_variable_set(:@sequence, 0xFFFE)
      client.instance_variable_set(:@time, 0)

      client.send(:increment_packet_headers)

      expect(client.instance_variable_get(:@sequence)).to eq(0xFFFF)
    end
  end
end
