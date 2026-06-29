# frozen_string_literal: true

require 'onyxcord'

describe 'gateway event cache usage' do
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
