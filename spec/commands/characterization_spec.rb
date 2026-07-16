# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Commands::Bot, 'current characterization baseline (T0)' do
  let(:server) { double('server', id: 123) }
  let(:text_channel_data) { { 'id' => 123, 'name' => 'general', 'type' => 0 } }
  let(:user_id) { 321 }

  def command_event_double
    double('event').tap do |event|
      allow(event).to receive(:command=)
      allow(event).to receive(:drain_into) { |e| e }
      allow(event).to receive(:server) { server }
      allow(event).to receive(:respond)
      allow(event).to receive(:author) do
        double('member', id: user_id, roles: [], permission?: true, webhook?: false)
      end
      allow(event).to receive(:user) { event.author }
      allow(event).to receive(:bot) do
        double('bot', token: 'fake token', rate_limited?: false, attributes: {})
      end
      channel = OnyxCord::Channel.new(text_channel_data, event.bot, server)
      allow(event).to receive(:channel) { channel }
    end
  end

  context 'current chain semantics' do
    let(:bot) { OnyxCord::Commands::Bot.new(token: 'fake', help_available: false, advanced_functionality: true) }

    before do
      bot.command(:echo) { |_event, arg| arg }
      bot.command(:return_nil) { nil }
      bot.command(:return_false) { false }
      bot.command(:return_empty) { '' }
    end

    it 'documents the current handling of nil (stops chain in bare execute or returns empty string)' do
      event = command_event_double
      result = bot.execute_command(:return_nil, event, [], false, false)
      expect(result).to eq('')
    end

    it 'documents the current handling of false (returns "false" when called directly due to stringify)' do
      event = command_event_double
      result = bot.execute_command(:return_false, event, [], false, false)
      expect(result).to eq('false')
    end

    it 'documents empty string results' do
      event = command_event_double
      result = bot.execute_command(:return_empty, event, [], false, false)
      expect(result).to eq('')
    end

    it 'documents missing command behavior (returns nil)' do
      event = command_event_double
      result = bot.execute_command(:nonexistent, event, [], false, false)
      expect(result).to be_nil
    end

    it 'documents permission failure behavior (returns nil and responds if permission_message set)' do
      bot.command(:restricted, permission_level: 100, permission_message: 'Denied!') { 'secret' }
      event = command_event_double
      expect(event).to receive(:respond).with('Denied!')
      result = bot.execute_command(:restricted, event, [], false, true)
      expect(result).to be_nil
    end
  end

  context 'chain_usable behavior (T1 fixed)' do
    let(:bot) { OnyxCord::Commands::Bot.new(token: 'fake', help_available: false) }

    it 'allows commands with chain_usable: false when chained is false, and blocks when chained is true' do
      bot.command(:admin_only, chain_usable: false) { 'ok' }
      event = command_event_double
      
      # When not chained: executes normally
      result = bot.execute_command(:admin_only, event, [], false, false)
      expect(result).to eq('ok')

      # When chained: responds with error and blocks
      expect(event).to receive(:respond).with('Command `admin_only` cannot be used in a command chain!')
      result_chained = bot.execute_command(:admin_only, event, [], true, false)
      expect(result_chained).to eq('')
    end
  end
end
