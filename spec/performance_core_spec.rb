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
      'op' => OnyxCord::Internal::Gateway::Opcodes::DISPATCH,
      't' => type,
      's' => 1,
      'd' => data
    }
  end

  describe '.configure' do
    it 'uses hybrid mode by default' do
      bot = OnyxCord::Bot.new(token: 'fake_token', event_executor: :inline)

      expect(bot.mode).to eq(:hybrid)
    end

    it 'sets an optional event queue size for pool executors' do
      bot = OnyxCord::Bot.new(token: 'fake_token', event_queue_size: 3)

      expect(bot.event_executor.queue).to be_a(SizedQueue)
      expect(bot.event_executor.queue.max).to eq(3)
      bot.event_executor.shutdown
    end

    it 'sets global defaults for new bots' do
      OnyxCord.configure do |config|
        config.mode = :hybrid
        config.cache = :minimal
        config.event_executor = :inline
        config.event_queue_size = 5
      end

      bot = OnyxCord::Bot.new(token: 'fake_token')

      expect(bot.mode).to eq(:hybrid)
      expect(bot.cache_policy[:servers]).to be(true)
      expect(bot.cache_policy[:users]).to be(false)
      expect(bot.event_executor).to be_a(OnyxCord::Internal::EventExecutor::Inline)
    end
  end

  describe '#raw' do
    it 'matches raw dispatches by symbol' do
      received = []
      bot = build_bot(mode: :raw)

      bot.raw(:MESSAGE_CREATE) { |payload| received << payload }
      bot.send(:dispatch_packet, packet('MESSAGE_CREATE', 'content' => 'hello'))

      expect(received.first['d']['content']).to eq('hello')
    end

    it 'matches raw dispatches by string' do
      received = []
      bot = build_bot(mode: :raw)

      bot.raw('MESSAGE_CREATE') { |payload| received << payload }
      bot.send(:dispatch_packet, packet('MESSAGE_CREATE'))

      expect(received.length).to eq(1)
    end

    it 'matches raw dispatches by regexp' do
      received = []
      bot = build_bot(mode: :raw)

      bot.raw(/MESSAGE_/) { |payload| received << payload }
      bot.send(:dispatch_packet, packet('MESSAGE_DELETE'))

      expect(received.length).to eq(1)
    end

    it 'matches all raw dispatches without a filter' do
      received = []
      bot = build_bot(mode: :raw)

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

      expect(bot.instance_variable_get(:@servers).enabled?).to be false
      expect(bot.instance_variable_get(:@channels).enabled?).to be false
      expect(bot.instance_variable_get(:@users).enabled?).to be false
    end

    it 'allocates only server and channel maps for :minimal' do
      bot = build_bot(cache: :minimal)

      expect(bot.instance_variable_get(:@servers)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@servers).enabled?).to be true
      expect(bot.instance_variable_get(:@channels)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@channels).enabled?).to be true
      expect(bot.instance_variable_get(:@users).enabled?).to be false
      expect(bot.instance_variable_get(:@thread_members).enabled?).to be false
    end

    it 'allocates all cache maps for :full' do
      bot = build_bot(cache: :full)

      expect(bot.instance_variable_get(:@servers)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@servers).enabled?).to be true
      expect(bot.instance_variable_get(:@channels)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@channels).enabled?).to be true
      expect(bot.instance_variable_get(:@users)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@users).enabled?).to be true
      expect(bot.instance_variable_get(:@thread_members)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@thread_members).enabled?).to be true
    end

    it 'accepts hash overrides' do
      bot = build_bot(cache: { servers: true, users: true })

      expect(bot.instance_variable_get(:@servers)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@servers).enabled?).to be true
      expect(bot.instance_variable_get(:@users)).to be_a(OnyxCord::Cache::Stores::LruCacheStore)
      expect(bot.instance_variable_get(:@users).enabled?).to be true
      expect(bot.instance_variable_get(:@channels).enabled?).to be false
    end

    it 'reports and prunes cache stores' do
      bot = build_bot(cache: :full)
      bot.instance_variable_get(:@users)[1] = :user
      bot.instance_variable_get(:@channels)[2] = :channel

      stats = bot.cache_stats
      expect(stats[:users][:size]).to eq(1)
      expect(stats[:channels][:size]).to eq(1)
      expect(bot.prune_cache!(:users)[:users]).to eq(1)
      expect(bot.cache_stats[:users][:size]).to eq(0)
      expect(bot.cache_stats[:channels][:size]).to eq(1)
    end

    it 'reports runtime stats' do
      bot = build_bot(cache: :minimal)

      expect(bot.runtime_stats).to include(
        mode: :hybrid,
        event_executor: 'OnyxCord::Internal::EventExecutor::Inline',
        event_threads: 0,
        event_queue_size: 0
      )
      expect(bot.runtime_stats[:cache][:servers][:size]).to eq(0)
      expect(bot.runtime_stats[:cache][:channels][:size]).to eq(0)
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
