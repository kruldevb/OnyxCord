# frozen_string_literal: true

require 'onyxcord/gateway/client'
require 'onyxcord/internal/gateway/session'

describe OnyxCord::Gateway::Client do
  let(:logger) { double('Logger', debug: nil, info: nil, warn: nil, error: nil, good: nil, out: nil, log_exception: nil) }
  let(:bot) { double('Bot', logger: logger) }
  let(:gateway) { described_class.new(bot, 'token', nil, :stream, 0) }

  describe 'state machine' do
    it 'starts in idle state' do
      expect(gateway.state).to eq(:idle)
    end

    it 'tracks generation' do
      expect(gateway.generation).to eq(0)
    end
  end

  describe '#open?' do
    it 'returns false when not ready' do
      expect(gateway.open?).to be false
    end
  end

  describe 'reconnect behavior' do
    let(:session) { OnyxCord::Internal::Gateway::Session.new('sid', 'wss://resume.test') }

    before do
      session.suspend
      gateway.instance_variable_set(:@session, session)
    end

    it 'does not invalidate session before HELLO on reconnect' do
      # GW-0101: pre-HELLO reconnect should NOT invalidate the session
      # The session is suspended but not invalid, so should_resume? is true
      gateway.reconnect(resume: true)
      expect(session).to be_suspended
      expect(session).not_to be_invalid
      expect(session.should_resume?).to be true
    end

    it 'keeps a suspended session resumable after HELLO' do
      gateway.reconnect(resume: true)
      expect(session).to be_suspended
      expect(session).not_to be_invalid
      expect(session.should_resume?).to be true
    end

    it 'invalidates session when resume is false' do
      gateway.reconnect(resume: false)
      expect(session).to be_invalid
      expect(session.should_resume?).to be false
    end
  end

  describe 'heartbeat latency' do
    before do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(10.0, 10.042)
      allow(gateway).to receive(:enqueue_write)
    end

    it 'tracks latency from heartbeat ACKs' do
      gateway.send_heartbeat(1)
      gateway.__send__(:handle_heartbeat_ack)

      expect(gateway.latency).to be_within(0.001).of(0.042)
    end

    it 'sets last_heartbeat_acked to true' do
      gateway.__send__(:instance_variable_set, :@last_heartbeat_acked, false)
      gateway.send_heartbeat(1)
      gateway.__send__(:handle_heartbeat_ack)
      expect(gateway.instance_variable_get(:@last_heartbeat_acked)).to be true
    end
  end

  describe '#stop' do
    it 'sets stop_requested' do
      gateway.stop
      expect(gateway.instance_variable_get(:@stop_requested)).to be true
    end

    it 'transitions to stopped' do
      gateway.stop
      expect(gateway.state).to eq(:stopped)
    end
  end

  describe 'close code table' do
    it 'has entries for all 4000-4014 codes' do
      (4000..4014).each do |code|
        info = OnyxCord::Internal::Gateway.close_info(code)
        expect(info).to be_a(OnyxCord::Internal::Gateway::CloseCode)
        expect(info.code).to eq(code)
      end
    end

    it 'marks 4004 as fatal' do
      info = OnyxCord::Internal::Gateway.close_info(4004)
      expect(info.fatal?).to be true
      expect(info.reconnect?).to be false
    end

    it 'marks 4000 as recoverable and resumable' do
      info = OnyxCord::Internal::Gateway.close_info(4000)
      expect(info.reconnect?).to be true
      expect(info.resume?).to be true
      expect(info.fatal?).to be false
    end

    it 'marks 4014 as fatal' do
      info = OnyxCord::Internal::Gateway.close_info(4014)
      expect(info.fatal?).to be true
    end

    it 'returns default for unknown codes' do
      info = OnyxCord::Internal::Gateway.close_info(9999)
      expect(info.reconnect?).to be true
      expect(info.fatal?).to be false
    end
  end
end
