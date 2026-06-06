# frozen_string_literal: true

require 'onyxcord'

describe 'OnyxCord performance core' do
  before { OnyxCord.reset_configuration! }
  after { OnyxCord.reset_configuration! }

  def build_bot(**attributes)
    OnyxCord::Bot.new(token: 'fake_token', event_executor: :inline, **attributes)
  end

  def packet(type, data = {})
    {
      'op' => OnyxCord::Opcodes::DISPATCH,
      't' => type,
      's' => 1,
      'd' => data
    }
  end

  describe '.configure' do
    it 'sets global defaults for new bots' do
      OnyxCord.configure do |config|
        config.mode = :hybrid
        config.cache = :minimal
        config.event_executor = :inline
      end

      bot = OnyxCord::Bot.new(token: 'fake_token')

      expect(bot.mode).to eq(:hybrid)
      expect(bot.cache_policy[:servers]).to be(true)
      expect(bot.cache_policy[:users]).to be(false)
      expect(bot.event_executor).to be_a(OnyxCord::EventExecutor::Inline)
    end
  end

  describe '#raw' do
    it 'matches raw dispatches by symbol' do
      received = []
      bot = build_bot

      bot.raw(:MESSAGE_CREATE) { |payload| received << payload }
      bot.send(:dispatch_packet, packet('MESSAGE_CREATE', 'content' => 'hello'))

      expect(received.first['d']['content']).to eq('hello')
    end

    it 'matches raw dispatches by string' do
      received = []
      bot = build_bot

      bot.raw('MESSAGE_CREATE') { |payload| received << payload }
      bot.send(:dispatch_packet, packet('MESSAGE_CREATE'))

      expect(received.length).to eq(1)
    end

    it 'matches raw dispatches by regexp' do
      received = []
      bot = build_bot

      bot.raw(/MESSAGE_/) { |payload| received << payload }
      bot.send(:dispatch_packet, packet('MESSAGE_DELETE'))

      expect(received.length).to eq(1)
    end

    it 'matches all raw dispatches without a filter' do
      received = []
      bot = build_bot

      bot.raw { |payload| received << payload }
      bot.send(:dispatch_packet, packet('GUILD_CREATE'))

      expect(received.length).to eq(1)
    end

    it 'does not allocate object events in raw mode' do
      bot = build_bot(mode: :raw)
      bot.raw(:MESSAGE_CREATE) { nil }

      expect(bot).not_to receive(:handle_dispatch)
      expect(OnyxCord::Message).not_to receive(:new)
      expect(OnyxCord::Events::RawEvent).not_to receive(:new)

      bot.send(:dispatch_packet, packet('MESSAGE_CREATE', 'content' => 'hello'))
    end

    it 'runs raw handlers before object events in hybrid mode' do
      order = []
      bot = build_bot(mode: :hybrid, cache: :full)

      bot.raw(:UNSUPPORTED_EVENT) { order << :raw }
      bot.unknown { order << :object }
      bot.send(:dispatch_packet, packet('UNSUPPORTED_EVENT'))

      expect(order).to eq(%i[raw object])
    end
  end

  describe 'cache policy' do
    it 'does not allocate cache maps for :none' do
      bot = build_bot(cache: :none)

      expect(bot.instance_variable_get(:@servers)).to be_nil
      expect(bot.instance_variable_get(:@channels)).to be_nil
      expect(bot.instance_variable_get(:@users)).to be_nil
    end

    it 'allocates only server and channel maps for :minimal' do
      bot = build_bot(cache: :minimal)

      expect(bot.instance_variable_get(:@servers)).to eq({})
      expect(bot.instance_variable_get(:@channels)).to eq({})
      expect(bot.instance_variable_get(:@users)).to be_nil
      expect(bot.instance_variable_get(:@thread_members)).to be_nil
    end

    it 'allocates all cache maps for :full' do
      bot = build_bot(cache: :full)

      expect(bot.instance_variable_get(:@servers)).to eq({})
      expect(bot.instance_variable_get(:@channels)).to eq({})
      expect(bot.instance_variable_get(:@users)).to eq({})
      expect(bot.instance_variable_get(:@thread_members)).to eq({})
    end

    it 'accepts hash overrides' do
      bot = build_bot(cache: { servers: true, users: true })

      expect(bot.instance_variable_get(:@servers)).to eq({})
      expect(bot.instance_variable_get(:@users)).to eq({})
      expect(bot.instance_variable_get(:@channels)).to be_nil
    end
  end

  describe 'intents' do
    it 'uses minimal intents by default' do
      bot = build_bot

      expect(bot.gateway.intents).to eq(OnyxCord::MINIMAL_INTENTS)
    end

    it 'normalizes official Discord intent aliases' do
      bot = build_bot(intents: %i[guilds guild_messages message_content])

      expect(bot.gateway.intents).to eq(
        OnyxCord::INTENTS[:servers] |
        OnyxCord::INTENTS[:server_messages] |
        OnyxCord::INTENTS[:message_content]
      )
    end
  end
end
