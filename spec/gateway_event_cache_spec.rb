# frozen_string_literal: true

require 'onyxcord'

describe 'gateway event cache usage' do
  it 'updates voice state from the cached server without resolving server or channel through REST' do
    bot = OnyxCord::Bot.new(token: 'fake_token')
    old_voice_state = instance_double(OnyxCord::VoiceState, channel_id: 111, voice_channel: nil)
    server = instance_double(OnyxCord::Server, channels: [], voice_states: { 200 => old_voice_state })
    data = {
      'guild_id' => '100',
      'user_id' => '200',
      'channel_id' => '300',
      'session_id' => 'voice-session'
    }

    bot.instance_variable_set(:@servers, 100 => server)
    bot.instance_variable_set(:@channels, {})
    bot.instance_variable_set(:@voices, {})
    bot.instance_variable_set(:@profile, instance_double(OnyxCord::Profile, id: 999))

    expect(bot).not_to receive(:server)
    expect(bot).not_to receive(:channel)
    expect(server).to receive(:update_voice_state).with(data)

    expect(bot.send(:update_voice_state, data)).to eq(111)
  end

  it 'caches guild updates when the guild is not already cached' do
    bot = OnyxCord::Bot.new(token: 'fake_token')
    data = { 'id' => '100', 'name' => 'Guild' }

    bot.instance_variable_set(:@servers, {})
    expect(bot).to receive(:ensure_server).with(data, true)

    bot.send(:update_guild, data)
  end

  it 'builds channel create events from the payload without resolving the channel through REST' do
    bot = instance_double(OnyxCord::Bot)
    server = instance_double(OnyxCord::Server, id: 100)
    data = {
      'id' => '300',
      'guild_id' => '100',
      'type' => OnyxCord::Channel::TYPES[:voice],
      'name' => 'Voice'
    }

    bot.instance_variable_set(:@channels, {})
    bot.instance_variable_set(:@servers, 100 => server)
    expect(bot).not_to receive(:channel)

    event = OnyxCord::Events::ChannelCreateEvent.new(data, bot)

    expect(event.channel.id).to eq(300)
    expect(event.channel.server).to eq(server)
  end
end
