# frozen_string_literal: true

require 'onyxcord'

describe 'Per-bot logger' do
  it 'creates a separate logger per bot' do
    bot1 = OnyxCord::Bot.new(token: 'token1', log_mode: :debug)
    bot2 = OnyxCord::Bot.new(token: 'token2', log_mode: :quiet)

    expect(bot1.logger).to be_a(OnyxCord::Logger)
    expect(bot2.logger).to be_a(OnyxCord::Logger)
    expect(bot1.logger).not_to eq(bot2.logger)
  end

  it 'does not mutate the global LOGGER' do
    original_fancy = OnyxCord::LOGGER.instance_variable_get(:@fancy)
    bot = OnyxCord::Bot.new(token: 'test', log_mode: :debug, fancy_log: true)
    expect(OnyxCord::LOGGER.instance_variable_get(:@fancy)).to eq(original_fancy)
  end
end
