# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::OptionBuilder do
  describe '#subcommand' do
    it 'creates a subcommand with nested options' do
      builder = described_class.new
      builder.subcommand('echo', 'Echo back') do |sub|
        sub.string('message', 'The message', required: true)
      end
      expect(builder.to_a.size).to eq(1)
      cmd = builder.to_a.first
      expect(cmd[:type]).to eq(1)
      expect(cmd[:name]).to eq('echo')
      expect(cmd[:options].size).to eq(1)
    end
  end

  describe '#subcommand_group' do
    it 'creates a subcommand group with nested subcommands' do
      builder = described_class.new
      builder.subcommand_group('fun', 'Fun commands') do |group|
        group.subcommand('8ball', 'Ask the magic 8ball') do |sub|
          sub.string('question', 'What do you ask?')
        end
      end
      expect(builder.to_a.size).to eq(1)
      group = builder.to_a.first
      expect(group[:type]).to eq(2)
      expect(group[:options].size).to eq(1)
    end
  end

  describe '#string' do
    it 'creates a string option' do
      builder = described_class.new
      builder.string('name', 'Your name', required: true, min_length: 1, max_length: 32)
      opt = builder.to_a.first
      expect(opt[:type]).to eq(3)
      expect(opt[:name]).to eq('name')
      expect(opt[:required]).to be true
      expect(opt[:min_length]).to eq(1)
      expect(opt[:max_length]).to eq(32)
    end

    it 'creates a string option with choices' do
      builder = described_class.new
      builder.string('color', 'Pick a color', choices: { 'Red' => 'red', 'Blue' => 'blue' })
      opt = builder.to_a.first
      expect(opt[:choices]).to eq([{ name: 'Red', value: 'red' }, { name: 'Blue', value: 'blue' }])
    end

    it 'creates a string option with autocomplete' do
      builder = described_class.new
      builder.string('query', 'Search', autocomplete: true)
      opt = builder.to_a.first
      expect(opt[:autocomplete]).to be true
    end
  end

  describe '#integer' do
    it 'creates an integer option with constraints' do
      builder = described_class.new
      builder.integer('count', 'A count', min_value: 0, max_value: 100)
      opt = builder.to_a.first
      expect(opt[:type]).to eq(4)
      expect(opt[:min_value]).to eq(0)
      expect(opt[:max_value]).to eq(100)
    end
  end

  describe '#boolean' do
    it 'creates a boolean option' do
      builder = described_class.new
      builder.boolean('flag', 'Enable flag', required: true)
      opt = builder.to_a.first
      expect(opt[:type]).to eq(5)
      expect(opt[:required]).to be true
    end
  end

  describe '#user' do
    it 'creates a user option' do
      builder = described_class.new
      builder.user('target', 'User to target', required: true)
      opt = builder.to_a.first
      expect(opt[:type]).to eq(6)
    end
  end

  describe '#channel' do
    it 'creates a channel option with types' do
      builder = described_class.new
      builder.channel('channel', 'Target channel', types: %i[text voice])
      opt = builder.to_a.first
      expect(opt[:type]).to eq(7)
      expect(opt[:channel_types]).to eq([0, 2])
    end
  end

  describe '#role' do
    it 'creates a role option' do
      builder = described_class.new
      builder.role('role', 'Target role')
      opt = builder.to_a.first
      expect(opt[:type]).to eq(8)
    end
  end

  describe '#mentionable' do
    it 'creates a mentionable option' do
      builder = described_class.new
      builder.mentionable('target', 'Mention someone')
      opt = builder.to_a.first
      expect(opt[:type]).to eq(9)
    end
  end

  describe '#number' do
    it 'creates a number option with constraints' do
      builder = described_class.new
      builder.number('value', 'A value', min_value: 0.0, max_value: 1.0)
      opt = builder.to_a.first
      expect(opt[:type]).to eq(10)
      expect(opt[:min_value]).to eq(0.0)
      expect(opt[:max_value]).to eq(1.0)
    end
  end

  describe '#attachment' do
    it 'creates an attachment option' do
      builder = described_class.new
      builder.attachment('file', 'File to upload', required: true)
      opt = builder.to_a.first
      expect(opt[:type]).to eq(11)
      expect(opt[:required]).to be true
    end
  end

  describe 'CHANNEL_TYPES' do
    it 'maps channel type symbols to integers' do
      expect(described_class::CHANNEL_TYPES[:text]).to eq(0)
      expect(described_class::CHANNEL_TYPES[:dm]).to eq(1)
      expect(described_class::CHANNEL_TYPES[:voice]).to eq(2)
      expect(described_class::CHANNEL_TYPES[:category]).to eq(4)
      expect(described_class::CHANNEL_TYPES[:news]).to eq(5)
      expect(described_class::CHANNEL_TYPES[:public_thread]).to eq(11)
      expect(described_class::CHANNEL_TYPES[:private_thread]).to eq(12)
      expect(described_class::CHANNEL_TYPES[:stage]).to eq(13)
    end
  end

  describe 'localizations' do
    it 'includes name_localizations and description_localizations on string options' do
      builder = described_class.new
      builder.string(:greeting, 'Say hello',
                     name_localizations: { 'pt-BR': 'saudacao', de: 'gruss' },
                     description_localizations: { 'pt-BR': 'Diga ola', de: 'Sag Hallo' })
      opt = builder.to_a.first
      expect(opt[:name_localizations]).to eq({ 'pt-BR': 'saudacao', de: 'gruss' })
      expect(opt[:description_localizations]).to eq({ 'pt-BR': 'Diga ola', de: 'Sag Hallo' })
    end

    it 'includes choice_localizations on string options' do
      builder = described_class.new
      builder.string(:color, 'Pick a color',
                     choices: { 'Red' => 1, 'Blue' => 2 },
                     choice_localizations: { Red: { 'pt-BR': 'Vermelho' }, Blue: { 'pt-BR': 'Azul' } })
      opt = builder.to_a.first
      expect(opt[:choices][0][:name_localizations]).to eq({ 'pt-BR': 'Vermelho' })
      expect(opt[:choices][1][:name_localizations]).to eq({ 'pt-BR': 'Azul' })
    end

    it 'supports localizations on integer options' do
      builder = described_class.new
      builder.integer(:count, 'Number',
                      name_localizations: { 'pt-BR': 'quantidade' },
                      description_localizations: { 'pt-BR': 'Numero' })
      opt = builder.to_a.first
      expect(opt[:name_localizations]).to eq({ 'pt-BR': 'quantidade' })
    end

    it 'supports localizations on number options' do
      builder = described_class.new
      builder.number(:ratio, 'Ratio',
                     name_localizations: { ja: 'heikin' },
                     description_localizations: { ja: 'ヒテイ' })
      opt = builder.to_a.first
      expect(opt[:name_localizations]).to eq({ ja: 'heikin' })
    end

    it 'omits localizations when nil' do
      builder = described_class.new
      builder.string(:plain, 'No locs')
      opt = builder.to_a.first
      expect(opt).not_to have_key(:name_localizations)
      expect(opt).not_to have_key(:description_localizations)
    end
  end
end
