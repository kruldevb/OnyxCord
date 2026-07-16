# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::Context do
  let(:bot) { instance_double(OnyxCord::Bot) }
  let(:event) do
    double('Event',
           bot: bot,
           user: double('User', id: 1),
           server: double('Server', id: 10),
           server_id: 10,
           channel: double('Channel', id: 20),
           channel_id: 20,
           user_locale: 'pt-BR',
           server_locale: 'en-US')
  end

  let(:command) do
    double('Command', name: 'test', type: :chat_input, root_executor: proc {})
  end

  subject(:context) { described_class.new(event, command) }

  describe 'basic delegates' do
    it { expect(context.bot).to be(bot) }
    it { expect(context.user).to be(event.user) }
    it { expect(context.guild).to be(event.server) }
    it { expect(context.server).to be(event.server) }
    it { expect(context.channel).to be(event.channel) }
    it { expect(context.guild_id).to eq(10) }
    it { expect(context.server_id).to eq(10) }
    it { expect(context.channel_id).to eq(20) }
    it { expect(context.locale).to eq('pt-BR') }
    it { expect(context.guild_locale).to eq('en-US') }
  end

  describe 'INT-0105: options flat' do
    it 'parses flat options from event data' do
      data = {
        'options' => [
          { 'name' => 'message', 'value' => 'hello', 'type' => 3 },
          { 'name' => 'count', 'value' => 42, 'type' => 4 }
        ]
      }
      allow(event).to receive(:data).and_return(data)
      allow(event).to receive(:respond_to?).with(:data).and_return(true)
      allow(event).to receive(:resolved).and_return(nil)
      allow(event).to receive(:respond_to?).with(:resolved).and_return(true)

      expect(context.options).to eq(message: 'hello', count: 42)
    end
  end

  describe 'INT-0105: options with subcommand' do
    it 'descends into subcommand' do
      data = {
        'options' => [
          {
            'name' => 'echo', 'type' => 1,
            'options' => [
              { 'name' => 'message', 'value' => 'hi', 'type' => 3 }
            ]
          }
        ]
      }
      allow(event).to receive(:data).and_return(data)
      allow(event).to receive(:respond_to?).with(:data).and_return(true)
      allow(event).to receive(:resolved).and_return(nil)
      allow(event).to receive(:respond_to?).with(:resolved).and_return(true)

      expect(context.options).to eq(message: 'hi')
    end
  end

  describe 'INT-0105: options with subcommand group' do
    it 'descends group → subcommand → leaf' do
      data = {
        'options' => [
          {
            'name' => 'roles', 'type' => 2,
            'options' => [
              {
                'name' => 'add', 'type' => 1,
                'options' => [
                  { 'name' => 'role', 'value' => '123', 'type' => 8 }
                ]
              }
            ]
          }
        ]
      }
      allow(event).to receive(:data).and_return(data)
      allow(event).to receive(:respond_to?).with(:data).and_return(true)
      allow(event).to receive(:resolved).and_return(nil)
      allow(event).to receive(:respond_to?).with(:resolved).and_return(true)

      expect(context.options).to eq(role: '123')
    end
  end

  describe 'INT-0105: resolved values' do
    it 'resolves USER from resolved data' do
      resolved_user = double('User', id: 99)
      resolved = double('Resolved', :[] => { 99 => resolved_user })
      data = { 'options' => [{ 'name' => 'target', 'value' => '99', 'type' => 6 }] }

      allow(event).to receive(:data).and_return(data)
      allow(event).to receive(:respond_to?).with(:data).and_return(true)
      allow(event).to receive(:resolved).and_return(resolved)
      allow(event).to receive(:respond_to?).with(:resolved).and_return(true)

      # type 6 = USER — busca em members e users
      allow(resolved).to receive(:respond_to?).with(:[]).and_return(true)
      allow(resolved).to receive(:respond_to?).with(:members).and_return(true)
      allow(resolved).to receive(:[]).with(:users).and_return({ 99 => resolved_user })

      expect(context.options[:target]).to be(resolved_user)
    end
  end

  describe 'INT-0301: memoized options' do
    it 'freezes and reuses snapshot' do
      data = { 'options' => [{ 'name' => 'msg', 'value' => 'hey', 'type' => 3 }] }
      allow(event).to receive(:data).and_return(data)
      allow(event).to receive(:respond_to?).with(:data).and_return(true)
      allow(event).to receive(:resolved).and_return(nil)
      allow(event).to receive(:respond_to?).with(:resolved).and_return(true)

      first = context.options
      second = context.options
      expect(first).to be_frozen
      expect(second).to be_frozen
      expect(first).to equal(second)
    end
  end

  describe 'INT-0209: target for USER/MESSAGE' do
    it 'exposes target and target_id' do
      allow(event).to receive(:respond_to?).with(:target).and_return(true)
      allow(event).to receive(:respond_to?).with(:target_id).and_return(true)
      allow(event).to receive(:target).and_return(double('User'))
      allow(event).to receive(:target_id).and_return(88)

      expect(context.target).to be(event.target)
      expect(context.target_id).to eq(88)
    end

    it 'exposes command_id' do
      allow(event).to receive(:respond_to?).with(:command_id).and_return(true)
      allow(event).to receive(:command_id).and_return(12345)

      expect(context.command_id).to eq(12345)
    end
  end
end