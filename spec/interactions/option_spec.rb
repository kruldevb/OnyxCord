# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::Option do
  describe 'OPTION_TYPES' do
    it 'includes all option types' do
      expect(described_class::OPTION_TYPES).to include(
        subcommand: 1,
        string: 3,
        integer: 4,
        boolean: 5,
        user: 6,
        channel: 7,
        role: 8,
        mentionable: 9,
        number: 10,
        attachment: 11
      )
    end
  end

  describe '#to_h' do
    it 'serializes basic string option' do
      opt = described_class.new('name', 'Your name', :string)
      hash = opt.to_h
      expect(hash[:name]).to eq('name')
      expect(hash[:description]).to eq('Your name')
      expect(hash[:type]).to eq(3)
    end

    it 'includes required when true' do
      opt = described_class.new('name', 'Your name', :string, required: true)
      expect(opt.to_h[:required]).to be true
    end

    it 'does not include required when nil' do
      opt = described_class.new('name', 'Your name', :string)
      expect(opt.to_h).not_to have_key(:required)
    end

    it 'includes min_length and max_length' do
      opt = described_class.new('text', 'Some text', :string, min_length: 1, max_length: 100)
      hash = opt.to_h
      expect(hash[:min_length]).to eq(1)
      expect(hash[:max_length]).to eq(100)
    end

    it 'includes min_value and max_value for integer' do
      opt = described_class.new('count', 'A count', :integer, min_value: 0, max_value: 10)
      hash = opt.to_h
      expect(hash[:min_value]).to eq(0)
      expect(hash[:max_value]).to eq(10)
    end

    it 'includes autocomplete' do
      opt = described_class.new('query', 'Search', :string, autocomplete: true)
      expect(opt.to_h[:autocomplete]).to be true
    end

    it 'does not include autocomplete when nil' do
      opt = described_class.new('query', 'Search', :string)
      expect(opt.to_h).not_to have_key(:autocomplete)
    end

    it 'includes channel_types' do
      opt = described_class.new('channel', 'Pick channel', :channel, channel_types: [0, 2])
      expect(opt.to_h[:channel_types]).to eq([0, 2])
    end

    it 'serializes choices' do
      opt = described_class.new('color', 'Pick color', :string, choices: { 'Red' => 'red', 'Blue' => 'blue' })
      hash = opt.to_h
      expect(hash[:choices]).to eq([
                                     { name: 'Red', value: 'red' },
                                     { name: 'Blue', value: 'blue' }
                                   ])
    end

    it 'includes choice_localizations' do
      opt = described_class.new('color', 'Pick color', :string,
                                choices: { 'Red' => 'red' },
                                choice_localizations: { 'Red' => { 'pt-BR' => 'Vermelho' } })
      hash = opt.to_h
      expect(hash[:choices].first[:name_localizations]).to eq({ 'pt-BR' => 'Vermelho' })
    end

    it 'does not add name_localizations to choices without localizations' do
      opt = described_class.new('color', 'Pick color', :string,
                                choices: { 'Red' => 'red', 'Blue' => 'blue' },
                                choice_localizations: { 'Red' => { 'pt-BR' => 'Vermelho' } })
      hash = opt.to_h
      expect(hash[:choices].last).not_to have_key(:name_localizations)
    end

    it 'includes name_localizations on option' do
      opt = described_class.new('name', 'Your name', :string, name_localizations: { 'pt-BR' => 'nome' })
      expect(opt.to_h[:name_localizations]).to eq({ 'pt-BR' => 'nome' })
    end

    it 'includes description_localizations on option' do
      opt = described_class.new('name', 'Your name', :string, description_localizations: { 'pt-BR' => 'Seu nome' })
      expect(opt.to_h[:description_localizations]).to eq({ 'pt-BR' => 'Seu nome' })
    end
  end

  describe 'subcommand' do
    it 'creates a subcommand option' do
      parent = described_class.new('manage', 'Manage', :subcommand)
      sub = parent.subcommand('role', 'Manage roles')
      expect(sub.type).to eq(:subcommand)
      expect(parent.options.size).to eq(1)
    end
  end

  describe 'option DSL methods' do
    it 'defines string options via method' do
      opt = described_class.new('group', 'Group', :subcommand_group)
      opt.string(:query, 'Search query', required: true)
      expect(opt.options.size).to eq(1)
      expect(opt.options.first.type).to eq(3)
    end

    it 'defines integer options via method' do
      opt = described_class.new('group', 'Group', :subcommand_group)
      opt.integer(:count, 'Number', min_value: 1, max_value: 50)
      expect(opt.options.size).to eq(1)
      expect(opt.options.first.type).to eq(4)
    end

    it 'defines boolean options via method' do
      opt = described_class.new('group', 'Group', :subcommand_group)
      opt.boolean(:flag, 'Enable flag')
      expect(opt.options.size).to eq(1)
      expect(opt.options.first.type).to eq(5)
    end
  end
end
