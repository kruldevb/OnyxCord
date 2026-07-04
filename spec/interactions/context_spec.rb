# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::Context do
  let(:event) do
    double('event',
           bot: double('bot'),
           user: double('user', id: 123),
           server: double('server'),
           server_id: 456,
           channel: double('channel'),
           channel_id: 789,
           data: { 'options' => [{ 'name' => 'query', 'value' => 'hello' }] },
           user_locale: 'en-US',
           server_locale: 'pt-BR',
           respond: nil,
           defer: nil,
           edit_response: nil,
           delete_response: nil,
           send_message: nil)
  end

  let(:command) { double('command') }
  let(:context) { described_class.new(event, command) }

  describe '#bot' do
    it 'delegates to event.bot' do
      expect(context.bot).to equal(event.bot)
    end
  end

  describe '#user' do
    it 'delegates to event.user' do
      expect(context.user).to equal(event.user)
    end
  end

  describe '#guild' do
    it 'delegates to event.server' do
      expect(context.guild).to equal(event.server)
    end
  end

  describe '#guild_id' do
    it 'delegates to event.server_id' do
      expect(context.guild_id).to eq(456)
    end
  end

  describe '#channel' do
    it 'delegates to event.channel' do
      expect(context.channel).to equal(event.channel)
    end
  end

  describe '#channel_id' do
    it 'delegates to event.channel_id' do
      expect(context.channel_id).to eq(789)
    end
  end

  describe '#server' do
    it 'delegates to event.server' do
      expect(context.server).to equal(event.server)
    end
  end

  describe '#server_id' do
    it 'delegates to event.server_id' do
      expect(context.server_id).to eq(456)
    end
  end

  describe '#locale' do
    it 'returns the user locale' do
      expect(context.locale).to eq('en-US')
    end
  end

  describe '#guild_locale' do
    it 'returns the server locale' do
      expect(context.guild_locale).to eq('pt-BR')
    end
  end

  describe '#options' do
    it 'parses options from event data' do
      expect(context.options).to eq({ query: 'hello' })
    end

    it 'returns empty hash when no options' do
      event_no_opts = double('event', data: {})
      ctx = described_class.new(event_no_opts, command)
      expect(ctx.options).to eq({})
    end

    it 'returns empty hash when no data' do
      event_nil = double('event', data: nil)
      ctx = described_class.new(event_nil, command)
      expect(ctx.options).to eq({})
    end
  end

  describe '#respond' do
    it 'delegates to event.respond' do
      expect(event).to receive(:respond).with(content: 'hi')
      context.respond(content: 'hi')
    end
  end

  describe '#defer' do
    it 'delegates to event.defer' do
      expect(event).to receive(:defer).with(ephemeral: true)
      context.defer(ephemeral: true)
    end
  end

  describe '#edit_original' do
    it 'delegates to event.edit_response' do
      expect(event).to receive(:edit_response).with(content: 'edited')
      context.edit_original(content: 'edited')
    end
  end

  describe '#delete_original' do
    it 'delegates to event.delete_response' do
      expect(event).to receive(:delete_response)
      context.delete_original
    end
  end

  describe '#followup' do
    it 'delegates to event.send_message' do
      expect(event).to receive(:send_message).with(content: 'followup')
      context.followup(content: 'followup')
    end
  end

  describe '#member' do
    it 'returns nil when event has no interaction' do
      event_no_interaction = double('event', respond_to?: false)
      ctx = described_class.new(event_no_interaction, command)
      expect(ctx.member).to be_nil
    end
  end
end
