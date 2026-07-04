# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::Command do
  describe 'TYPES' do
    it 'includes all Discord command types' do
      expect(described_class::TYPES).to eq(
        chat_input: 1,
        user: 2,
        message: 3,
        primary_entry_point: 4
      )
    end
  end

  describe '.chat_input' do
    it 'creates a chat input command' do
      cmd = described_class.chat_input('ping', description: 'Pong!')
      expect(cmd.name).to eq('ping')
      expect(cmd.description).to eq('Pong!')
      expect(cmd.type).to eq(:chat_input)
    end

    it 'accepts attributes' do
      cmd = described_class.chat_input('ping', description: 'Pong!', nsfw: true, dm_permission: false)
      expect(cmd.to_h[:nsfw]).to be true
      expect(cmd.to_h[:dm_permission]).to be false
    end
  end

  describe '.user' do
    it 'creates a user command with empty description' do
      cmd = described_class.user('profile')
      expect(cmd.name).to eq('profile')
      expect(cmd.description).to eq('')
      expect(cmd.type).to eq(:user)
    end
  end

  describe '.message' do
    it 'creates a message command with empty description' do
      cmd = described_class.message('translate')
      expect(cmd.name).to eq('translate')
      expect(cmd.description).to eq('')
      expect(cmd.type).to eq(:message)
    end
  end

  describe '.primary_entry_point' do
    it 'creates a primary entry point command' do
      cmd = described_class.primary_entry_point('launch', description: 'Launch the activity')
      expect(cmd.name).to eq('launch')
      expect(cmd.description).to eq('Launch the activity')
      expect(cmd.type).to eq(:primary_entry_point)
    end
  end

  describe '#to_h' do
    it 'includes description for chat_input' do
      cmd = described_class.chat_input('test', description: 'A test')
      hash = cmd.to_h
      expect(hash[:description]).to eq('A test')
    end

    it 'includes description for primary_entry_point' do
      cmd = described_class.primary_entry_point('test', description: 'A test')
      hash = cmd.to_h
      expect(hash[:description]).to eq('A test')
    end

    it 'does not include description for user commands' do
      cmd = described_class.user('test')
      hash = cmd.to_h
      expect(hash).not_to have_key(:description)
    end

    it 'does not include description for message commands' do
      cmd = described_class.message('test')
      hash = cmd.to_h
      expect(hash).not_to have_key(:description)
    end

    it 'includes name_localizations' do
      cmd = described_class.chat_input('test', description: 'Test', name_localizations: { 'pt-BR': 'teste' })
      expect(cmd.to_h[:name_localizations]).to eq({ 'pt-BR': 'teste' })
    end

    it 'includes description_localizations' do
      cmd = described_class.chat_input('test', description: 'Test', description_localizations: { 'pt-BR': 'Um teste' })
      expect(cmd.to_h[:description_localizations]).to eq({ 'pt-BR': 'Um teste' })
    end

    it 'includes default_member_permissions as string' do
      cmd = described_class.chat_input('test', description: 'Test', default_member_permissions: 8)
      expect(cmd.to_h[:default_member_permissions]).to eq('8')
    end

    it 'includes dm_permission (default true)' do
      cmd = described_class.chat_input('test', description: 'Test')
      expect(cmd.to_h[:dm_permission]).to be true
    end

    it 'includes dm_permission when false' do
      cmd = described_class.chat_input('test', description: 'Test', dm_permission: false)
      expect(cmd.to_h[:dm_permission]).to be false
    end

    it 'includes nsfw when true' do
      cmd = described_class.chat_input('test', description: 'Test', nsfw: true)
      expect(cmd.to_h[:nsfw]).to be true
    end

    it 'does not include nsfw when false' do
      cmd = described_class.chat_input('test', description: 'Test')
      expect(cmd.to_h).not_to have_key(:nsfw)
    end

    it 'includes contexts' do
      cmd = described_class.chat_input('test', description: 'Test', contexts: [0, 1])
      expect(cmd.to_h[:contexts]).to eq([0, 1])
    end

    it 'includes integration_types' do
      cmd = described_class.chat_input('test', description: 'Test', integration_types: [0, 1])
      expect(cmd.to_h[:integration_types]).to eq([0, 1])
    end
  end

  describe '#subcommand' do
    it 'adds a subcommand option' do
      cmd = described_class.chat_input('manage', description: 'Manage things')
      cmd.subcommand('role', 'Manage roles')
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(:subcommand)
    end
  end

  describe '#subcommand_group' do
    it 'adds a subcommand group option' do
      cmd = described_class.chat_input('manage', description: 'Manage things')
      cmd.subcommand_group('roles', 'Role management')
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(:subcommand_group)
    end
  end

  describe '#execute' do
    it 'stores the executor block' do
      cmd = described_class.chat_input('ping', description: 'Pong!')
      cmd.execute { |ctx| ctx.respond(content: 'Pong!') }
      expect(cmd.instance_variable_get(:@executor)).to be_a(Proc)
    end
  end

  describe '#call' do
    it 'calls the executor with context' do
      cmd = described_class.chat_input('ping', description: 'Pong!')
      called = false
      cmd.execute { |_ctx| called = true }
      cmd.call(double('context'))
      expect(called).to be true
    end

    it 'does nothing without executor' do
      cmd = described_class.chat_input('ping', description: 'Pong!')
      expect { cmd.call(double('context')) }.not_to raise_error
    end
  end

  describe 'option DSL' do
    it 'defines string options' do
      cmd = described_class.chat_input('echo', description: 'Echo back')
      cmd.string(:message, 'The message to echo', required: true)
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(3)
    end

    it 'defines integer options' do
      cmd = described_class.chat_input('calc', description: 'Calculate')
      cmd.integer(:num, 'A number', min_value: 0, max_value: 100)
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(4)
    end

    it 'defines boolean options' do
      cmd = described_class.chat_input('toggle', description: 'Toggle setting')
      cmd.boolean(:enabled, 'Enable?')
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(5)
    end

    it 'defines user options' do
      cmd = described_class.chat_input('kick', description: 'Kick user')
      cmd.user(:target, 'User to kick', required: true)
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(6)
    end

    it 'defines channel options with types' do
      cmd = described_class.chat_input('post', description: 'Post message')
      cmd.channel(:channel, 'Target channel', types: %i[text news])
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(7)
    end

    it 'defines number options' do
      cmd = described_class.chat_input('set', description: 'Set value')
      cmd.number(:value, 'The value', min_value: 0.0, max_value: 1.0)
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(10)
    end

    it 'defines attachment options' do
      cmd = described_class.chat_input('upload', description: 'Upload file')
      cmd.attachment(:file, 'File to upload', required: true)
      expect(cmd.options.size).to eq(1)
      expect(cmd.options.first.type).to eq(11)
    end
  end
end
