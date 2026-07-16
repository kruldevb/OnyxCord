# frozen_string_literal: true

require 'onyxcord'
require 'onyxcord/commands/ast_parser'

describe 'Parser fuzz testing' do
  let(:bot) do
    OnyxCord::Commands::Bot.new(token: 'token', help_available: false, advanced_functionality: true).tap do |b|
      b.command(:echo) { |event, *args| args.join(' ') }
      b.command(:test) { |event, *args| 'ok' }
    end
  end

  let(:attributes) { bot.attributes }

  def make_event
    double('event').tap do |event|
      allow(event).to receive :command=
      allow(event).to receive(:drain_into) { |e| e }
      allow(event).to receive(:server)
      allow(event).to receive(:channel)
      allow(event).to receive(:author) do
        double('member').tap do |member|
          allow(member).to receive(:id) { 123 }
          allow(member).to receive(:roles) { [] }
          allow(member).to receive(:permission?) { true }
          allow(member).to receive(:webhook?) { false }
        end
      end
      allow(event).to receive(:bot) { bot }
    end
  end

  FUZZ_CHARS = ['[', ']', '>', '"', '\\', "\n", "\t", "\ue001", "\ue002", "\ue003", "\ue004",
                nil, '', ' ', '  ', 'repeat:999999', 'repeat:-1', 'repeat:abc'].freeze

  it 'never crashes the lexer across 1000 malformed inputs' do
    1000.times do
      input = FUZZ_CHARS.sample(rand(1..5)).compact.join
      begin
        OnyxCord::Commands::AstParser::Lexer.new(input, attributes).tokenize
      rescue => e
        fail "Lexer crashed on #{input.inspect}: #{e.class}: #{e.message}"
      end
    end
  end

  it 'never crashes the parser across 1000 malformed inputs' do
    1000.times do
      input = FUZZ_CHARS.sample(rand(1..5)).compact.join
      begin
        tokens = OnyxCord::Commands::AstParser::Lexer.new(input, attributes).tokenize
        OnyxCord::Commands::AstParser::Parser.new(tokens, attributes).parse
      rescue => e
        fail "Parser crashed on #{input.inspect}: #{e.class}: #{e.message}"
      end
    end
  end

  it 'never crashes the executor across 1000 malformed inputs' do
    1000.times do
      input = FUZZ_CHARS.sample(rand(1..5)).compact.join
      begin
        event = make_event
        OnyxCord::Commands::AstParser.execute(input, bot, event)
      rescue OnyxCord::Commands::AstParser::ExecutionBudgetExceeded
        # Expected
      rescue => e
        fail "Executor crashed on #{input.inspect}: #{e.class}: #{e.message}"
      end
    end
  end

  it 'rejects inputs exceeding budget' do
    event = make_event
    result = OnyxCord::Commands::AstParser.execute('repeat:999999 echo test', bot, event)
    expect(result).not_to be_nil
  end
end
