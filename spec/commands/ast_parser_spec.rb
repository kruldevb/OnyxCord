# frozen_string_literal: true

require 'onyxcord'
require 'onyxcord/commands/ast_parser'

describe OnyxCord::Commands::AstParser do
  let(:server) { double('server', id: 123) }
  let(:text_channel_data) { load_data_file(:text_channel) }

  def command_event_double
    double('event').tap do |event|
      allow(event).to receive :command=
      allow(event).to receive(:drain_into) { |e| e }
      allow(event).to receive(:server)
      allow(event).to receive(:channel)
    end
  end

  def append_author_to_double(event)
    allow(event).to receive(:author) do
      double('member').tap do |member|
        allow(member).to receive(:id) { 321 }
        allow(member).to receive(:roles) { [] }
        allow(member).to receive(:permission?) { true }
        allow(member).to receive(:webhook?) { false }
      end
    end
  end

  def append_bot_to_double(event)
    allow(event).to receive(:bot) do
      double('bot').tap do |bot|
        allow(bot).to receive(:token) { 'fake token' }
        allow(bot).to receive(:rate_limited?) { false }
        allow(bot).to receive(:attributes) { {} }
      end
    end
  end

  def make_event
    command_event_double.tap do |event|
      append_author_to_double(event)
      append_bot_to_double(event)
    end
  end

  describe 'Lexer' do
    let(:attributes) do
      OnyxCord::Commands::Bot.new(token: 'token', help_available: false).attributes
    end

    it 'tokenizes a simple command' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('test', attributes).tokenize
      expect(tokens.length).to eq(1)
      expect(tokens.first.type).to eq(:literal)
      expect(tokens.first.value).to eq('test')
    end

    it 'tokenizes a command with arguments' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('test arg1 arg2', attributes).tokenize
      literals = tokens.select { |t| t.type == :literal }
      expect(literals.map(&:value)).to eq(['test', 'arg1', 'arg2'])
    end

    it 'tokenizes chain delimiters' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('a > b', attributes).tokenize
      types = tokens.select { |t| t.type != :space }.map(&:type)
      expect(types).to eq([:literal, :chain_delimiter, :literal])
    end

    it 'handles quoted strings' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('test "hello world"', attributes).tokenize
      literals = tokens.select { |t| t.type == :literal }
      expect(literals.map(&:value)).to eq(['test', "hello\ue002world"])
    end

    it 'handles sub-chains' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('[test]', attributes).tokenize
      types = tokens.select { |t| t.type != :literal }.map(&:type)
      expect(types).to include(:sub_chain_start, :sub_chain_end)
    end
  end

  describe 'Parser' do
    let(:attributes) do
      OnyxCord::Commands::Bot.new(token: 'token', help_available: false).attributes
    end

    it 'parses a single command' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('test arg1', attributes).tokenize
      root = OnyxCord::Commands::AstParser::Parser.new(tokens, attributes).parse
      expect(root).to be_a(OnyxCord::Commands::AstParser::ChainNode)
      expect(root.commands.length).to eq(1)
      expect(root.commands.first).to be_a(OnyxCord::Commands::AstParser::CommandNode)
      expect(root.commands.first.name).to eq(:test)
      expect(root.commands.first.arguments).to eq(['arg1'])
    end

    it 'parses a chain of commands' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('a 1 > b 2', attributes).tokenize
      root = OnyxCord::Commands::AstParser::Parser.new(tokens, attributes).parse
      expect(root.commands.length).to eq(2)
      expect(root.commands.map(&:name)).to eq([:a, :b])
    end

    it 'handles sub-chains' do
      tokens = OnyxCord::Commands::AstParser::Lexer.new('[a > b]', attributes).tokenize
      root = OnyxCord::Commands::AstParser::Parser.new(tokens, attributes).parse
      expect(root.commands.length).to eq(1)
      expect(root.commands.first).to be_a(OnyxCord::Commands::AstParser::SubchainNode)
    end
  end

  describe 'differential tests' do
    let(:bot) do
      OnyxCord::Commands::Bot.new(token: 'token', help_available: false, advanced_functionality: true).tap do |b|
        b.command(:echo) { |event, *args| args.join(' ') }
        b.command(:add) { |event, a, b_arg| (a.to_i + b_arg.to_i).to_s }
      end
    end

    it 'handles simple command with args' do
      event = make_event
      result = OnyxCord::Commands::AstParser.execute('echo hello world', bot, event)
      expect(result).to eq('hello world')
    end

    it 'handles simple command with multiple args' do
      event = make_event
      result = OnyxCord::Commands::AstParser.execute('add 2 3', bot, event)
      expect(result).to eq('5')
    end

    it 'handles chain of two commands' do
      event = make_event
      result = OnyxCord::Commands::AstParser.execute('echo first > echo second', bot, event)
      expect(result).to eq('second')
    end

    it 'handles command with quoted args' do
      event = make_event
      result = OnyxCord::Commands::AstParser.execute('echo "hello world"', bot, event)
      expect(result).to eq('hello world')
    end
  end
end
