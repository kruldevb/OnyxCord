# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::Registry do
  let(:bot) do
    bot = instance_double(OnyxCord::Bot, logger: double('logger', debug: nil, info: nil, warn: nil, error: nil, good: nil, out: nil, in: nil, log_exception: nil))
    allow(bot).to receive(:application_command).and_return(nil)
    allow(bot).to receive(:dispatch).and_return(nil)
    allow(bot).to receive(:raise_heartbeat_event).and_return(nil)
    allow(bot).to receive(:raise_event).and_return(nil)
    allow(bot).to receive(:notify_ready).and_return(nil)
    allow(bot).to receive(:profile).and_return(double('profile', id: 123))
    allow(bot).to receive(:token).and_return('test-token')
    allow(bot).to receive(:bulk_overwrite_global_application_commands).and_return(nil)
    allow(bot).to receive(:bulk_overwrite_guild_application_commands).and_return(nil)
    allow(bot).to receive(:get_application_commands).and_return([])
    bot
  end

  subject(:registry) { described_class.new(bot) }

  describe '#slash' do
    it 'registers a chat_input command with executor' do
      called = false
      cmd = registry.slash('ping', description: 'Pong!') do
        execute { |ctx| called = true }
      end
      expect(cmd.name).to eq('ping')
      expect(cmd.root_executor).to be_a(Proc)
    end

    it 'parses options from the block' do
      cmd = registry.slash('echo', description: 'Echo back') do
        string(:message, 'What to echo')
        execute { |ctx| nil }
      end
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.name).to eq('message')
    end
  end

  describe '#user' do
    it 'registers a user command' do
      cmd = registry.user('profile') do
        execute { |ctx| nil }
      end
      expect(cmd.type).to eq(:user)
    end
  end

  describe '#message' do
    it 'registers a message command' do
      cmd = registry.message('translate') do
        execute { |ctx| nil }
      end
      expect(cmd.type).to eq(:message)
    end
  end

  describe '#primary_entry_point' do
    it 'registers a primary entry point' do
      cmd = registry.primary_entry_point('launch', description: 'Launch', handler: :APP_HANDLER)
      expect(cmd.type).to eq(:primary_entry_point)
      expect(cmd.handler).to eq(:APP_HANDLER)
    end
  end

  describe 'INT-0106: type-keyed registration' do
    it 'allows same name with different types' do
      s1 = registry.slash('inspect', description: 'Inspect things') do
        execute { |ctx| nil }
      end
      s2 = registry.user('inspect') do
        execute { |ctx| nil }
      end

      type1 = OnyxCord::Interactions::Command::TYPES[:chat_input]
      type2 = OnyxCord::Interactions::Command::TYPES[:user]

      expect(registry.commands[[type1, 'inspect']]).to be(s1)
      expect(registry.commands[[type2, 'inspect']]).to be(s2)
    end
  end

  describe 'INT-0107: dry_run' do
    it 'returns a summary without calling API' do
      registry.slash('foo', description: 'bar') do
        execute { |ctx| nil }
      end
      summary = registry.sync!(dry_run: true)
      expect(summary[:create]).to include('foo')
      expect(summary[:total_local]).to eq(1)
    end
  end

  describe 'INT-0107: safe sync' do
    it 'raises when trying to wipe with empty registry' do
      expect {
        registry.sync_safe!(delete_unknown: true)
      }.to raise_error(ArgumentError, /empty/i)
    end
  end
end