# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Await do
  subject(:bot) { OnyxCord::Bot.new(token: 'fake_token') }

  describe '#add_await' do
    it 'creates a non-reusable await by default' do
      await = bot.add_await(:test_key, OnyxCord::Events::MessageEvent)
      expect(await.reusable).to be false
    end

    it 'creates a reusable await when specified' do
      await = bot.add_await(:test_key, OnyxCord::Events::MessageEvent, reusable: true)
      expect(await.reusable).to be true
    end
  end

  describe '#cancel_await' do
    it 'removes an await by key' do
      bot.add_await(:cancel_me, OnyxCord::Events::MessageEvent)
      expect(bot.cancel_await(:cancel_me)).to be true
    end

    it 'returns false for non-existent key' do
      expect(bot.cancel_await(:nonexistent)).to be false
    end
  end
end
