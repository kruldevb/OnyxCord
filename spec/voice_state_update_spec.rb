# frozen_string_literal: true

require 'onyxcord'

describe 'voice state updates' do
  it 'keeps the channel id even when the channel object is not cached' do
    state = OnyxCord::VoiceState.new(123)

    state.update(nil, false, false, false, false, 456)

    expect(state.channel_id).to eq(456)
    expect(state.voice_channel).to be_nil
  end

  it 'exposes raw old and current channel ids on the event' do
    server = instance_double(OnyxCord::Server, channels: [])
    bot = instance_double(OnyxCord::Bot)
    data = {
      'guild_id' => '100',
      'user_id' => '200',
      'channel_id' => '300',
      'session_id' => 'voice-session'
    }

    bot.instance_variable_set(:@servers, 100 => server)
    bot.instance_variable_set(:@channels, {})
    bot.instance_variable_set(:@users, {})
    expect(bot).not_to receive(:server)
    expect(bot).not_to receive(:channel)
    expect(bot).not_to receive(:user)

    event = OnyxCord::Events::VoiceStateUpdateEvent.new(data, 250, bot)

    expect(event.channel_id).to eq(300)
    expect(event.old_channel_id).to eq(250)
    expect(event.user_id).to eq(200)
  end

  it 'matches raw dispatch packets with symbol keys' do
    handler = OnyxCord::Events::RawDispatchHandler.new('VOICE_STATE_UPDATE', proc {})

    expect(handler.matches?({ t: 'VOICE_STATE_UPDATE', d: {} })).to be(true)
  end
end
