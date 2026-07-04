# frozen_string_literal: true

require 'onyxcord/gateway/client'

describe OnyxCord::Gateway::Client do
  let(:bot) { double('Bot') }
  let(:gateway) { described_class.new(bot, 'token', nil, :stream, 0) }

  it 'invalidates a suspended session when reconnecting before HELLO' do
    session = OnyxCord::Internal::Gateway::Session.new('sid', 'wss://resume.test')
    session.suspend
    gateway.instance_variable_set(:@session, session)
    gateway.instance_variable_set(:@received_hello, false)
    allow(gateway).to receive(:close)

    gateway.reconnect

    expect(session).to be_invalid
  end

  it 'keeps a suspended session resumable after HELLO' do
    session = OnyxCord::Internal::Gateway::Session.new('sid', 'wss://resume.test')
    session.suspend
    gateway.instance_variable_set(:@session, session)
    gateway.instance_variable_set(:@received_hello, true)
    allow(gateway).to receive(:close)

    gateway.reconnect

    expect(session).not_to be_invalid
  end

  it 'tracks latency from heartbeat ACKs' do
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(10.0, 10.042)
    allow(gateway).to receive(:send_packet)

    gateway.send_heartbeat(1)
    gateway.__send__(:handle_heartbeat_ack, 'op' => 11)

    expect(gateway.latency).to be_within(0.001).of(0.042)
  end
end
