# frozen_string_literal: true

describe 'OnyxCord loader' do
  it 'loads the canonical reorganized tree' do
    require 'onyxcord'

    expect(OnyxCord::REST::Channel).to respond_to(:create_message)
    expect(OnyxCord::Message).to be_a(Class)
    expect(OnyxCord::Gateway::Client).to be_a(Class)
    expect(OnyxCord::Internal::EventBus).to be_a(Module)
    expect(OnyxCord::Commands::Bot).to be < OnyxCord::Bot
    expect(OnyxCord::Voice::Client).to be_a(Class)
    expect(defined?(OnyxCord::Webhooks::Modal::RowBuilder)).to be_nil
  end

  it 'does not keep old API/data require paths' do
    expect { require 'onyxcord/api' }.to raise_error(LoadError)
    expect { require 'onyxcord/data/message' }.to raise_error(LoadError)
    expect { require 'onyxcord/commands/command_bot' }.to raise_error(LoadError)
    expect { require 'onyxcord/voice/voice_bot' }.to raise_error(LoadError)
  end
end
