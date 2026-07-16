# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Bot::Messaging::TemporaryMessage do
  let(:message) { double(:message, id: 123) }
  let(:thread) { double(:thread) }

  subject(:tmp_msg) { described_class.new(message, thread) }

  it 'exposes the message' do
    expect(tmp_msg.message).to eq(message)
  end

  it 'is not cancelled initially' do
    expect(tmp_msg.cancelled?).to be false
  end

  it 'cancels successfully' do
    expect(thread).to receive(:kill)
    expect(tmp_msg.cancel).to be true
    expect(tmp_msg.cancelled?).to be true
  end

  it 'returns false on double cancel' do
    expect(thread).to receive(:kill)
    tmp_msg.cancel
    expect(tmp_msg.cancel).to be false
  end
end

describe OnyxCord::Bot do
  subject(:bot) { described_class.new(token: 'fake_token') }

  describe '#parse_mentions' do
    it 'returns empty array for non-string input' do
      expect(bot.parse_mentions(nil)).to eq([])
      expect(bot.parse_mentions(123)).to eq([])
    end

    it 'parses user mentions' do
      user_a = double(:user_a)
      allow(bot).to receive(:user).with('123').and_return(user_a)
      expect(bot.parse_mentions('<@123>')).to eq([user_a])
    end

    it 'parses nickname mentions' do
      user_a = double(:user_a)
      allow(bot).to receive(:user).with('123').and_return(user_a)
      expect(bot.parse_mentions('<@!123>')).to eq([user_a])
    end

    it 'deduplicates user mentions' do
      user_a = double(:user_a)
      allow(bot).to receive(:user).with('123').and_return(user_a)
      result = bot.parse_mentions('<@123><@123>')
      expect(result).to eq([user_a])
    end

    it 'parses animated emoji' do
      result = bot.parse_mentions('<a:foo:456>')
      expect(result.first).to be_a(OnyxCord::Emoji)
      expect(result.first.animated).to be true
      expect(result.first.name).to eq('foo')
      expect(result.first.id).to eq(456)
    end

    it 'parses non-animated emoji' do
      result = bot.parse_mentions('<:bar:789>')
      expect(result.first).to be_a(OnyxCord::Emoji)
      expect(result.first.animated).to be false
      expect(result.first.name).to eq('bar')
      expect(result.first.id).to eq(789)
    end

    it 'rejects invalid emoji prefix' do
      expect(bot.parse_mentions('<b:foo:123>')).to eq([])
    end

    it 'rejects invalid mentions' do
      server = OnyxCord::Server.new({ 'id' => 1, 'name' => 'test', 'roles' => [], 'channels' => [], 'members' => [] }, bot)
      expect(bot.parse_mentions('<<@123<@?123><#123<:foo:123<b:foo:456><@abc><@!abc>', server)).to eq([])
    end
  end
end
