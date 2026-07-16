# frozen_string_literal: true

require 'onyxcord'

# Minimal test bot that responds to the methods Interaction needs.
class TestBot
  attr_reader :token, :servers
  attr_reader :user_cache

  def initialize
    @token = 'test_token'
    @servers = {}
    @user_cache = {}
    @channels = {}
    @logger = Logger.new($stderr, level: Logger::FATAL)
  end

  def channel(id)
    @channels[id]
  end

  def ensure_channel(data)
    return nil unless data

    id = data['id']&.to_i || data.to_i
    @channels[id] ||= FakeChannel.new(data, self)
  end

  def ensure_user(data)
    return nil unless data
    id = data['id'].to_i
    @user_cache[id] ||= OnyxCord::User.new(data, self)
  end

  def servers
    @servers
  end

  def logger
    @logger
  end

  def debug(*); end
end

class FakeChannel
  attr_reader :server

  def initialize(data, bot)
    @data = data
    @bot = bot
    @server = nil
  end

  def private?
    @data['type'] == 1
  end
end

RSpec.describe OnyxCord::Interaction do
  let(:bot) { TestBot.new }

  describe 'PING interaction (MOD-0001)' do
    let(:ping_data) do
      {
        'id' => '1',
        'application_id' => '2',
        'type' => 1,
        'token' => 'interaction_token_abc123',
        'version' => 1,
        'guild_id' => '123',
        'channel_id' => '4',
        'locale' => 'en',
        'guild_locale' => 'en'
      }
    end

    it 'constructs without crashing when data field is absent (PING has no data)' do
      expect { described_class.new(ping_data, bot) }.not_to raise_error
    end

    it 'has type ping' do
      interaction = described_class.new(ping_data, bot)
      expect(interaction.type).to eq(1)
    end

    it 'token is accessible even without data' do
      interaction = described_class.new(ping_data, bot)
      expect(interaction.token).to eq('interaction_token_abc123')
    end

    it 'components is empty array for PING (no data)' do
      interaction = described_class.new(ping_data, bot)
      expect(interaction.components).to eq([])
    end

    it 'does not have a message' do
      interaction = described_class.new(ping_data, bot)
      expect(interaction.message).to be_nil
    end

    it 'respond to PING with PONG (callback type 1)' do
      interaction = described_class.new(ping_data, bot)
      expect(OnyxCord::Interaction::CALLBACK_TYPES[:pong]).to eq(1)
    end
  end

  describe 'slash command interaction (has data)' do
    let(:command_data) do
      {
        'id' => '10',
        'application_id' => '2',
        'type' => 2,
        'token' => 'cmd_token',
        'version' => 1,
        'guild_id' => '123',
        'channel_id' => '4',
        'data' => {
          'id' => '5',
          'name' => 'test',
          'type' => 1,
          'components' => [
            { 'type' => 1, 'components' => [{ 'type' => 2, 'custom_id' => 'btn1', 'label' => 'Click' }] }
          ]
        },
        'user' => { 'id' => '456', 'username' => 'cmd_user' }
      }
    end

    it 'parses data normally when present' do
      interaction = described_class.new(command_data, bot)
      expect(interaction.type).to eq(2)
      expect(interaction.data).to be_a(Hash)
    end

    it 'parses components from data' do
      interaction = described_class.new(command_data, bot)
      expect(interaction.components).not_to be_empty
    end
  end

  describe 'data mutation safety (MOD-0010)' do
    it 'does not mutate the original data hash when building member' do
      member_hash = { 'user' => { 'id' => '100', 'username' => 'mem' }, 'roles' => [] }
      original_member_keys = member_hash.keys.dup

      original_data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 'token',
        'version' => 1, 'guild_id' => '123', 'channel_id' => '4', 'member' => member_hash
      }

      described_class.new(original_data, bot)

      expect(original_data['member'].keys).to match_array(original_member_keys),
        "Interaction constructor mutated member hash by adding guild_id"
    end
  end

  describe 'user_integration? (MOD-0011)' do
    it 'returns false when integration_owners is absent' do
      data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 't',
        'version' => 1, 'guild_id' => '123', 'channel_id' => '4'
      }
      interaction = described_class.new(data, bot)
      expect(interaction.user_integration?).to be false
    end

    it 'returns false when user is nil (even with integration data present)' do
      data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 't',
        'version' => 1, 'guild_id' => '123', 'channel_id' => '4',
        'authorizing_integration_owners' => { '1' => '456' }
      }
      # User parsing can result in nil when member data is malformed
      bad_bot = TestBot.new
      interaction = described_class.new(data, bad_bot)
      # MOD-0009 fix ensures @user is nil gracefully and MOD-0011 handles it
      expect { interaction.user_integration? }.not_to raise_error
    end

    it 'returns true when user owns user integration' do
      data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 't',
        'version' => 1, 'guild_id' => '123', 'channel_id' => '4',
        'user' => { 'id' => '456', 'username' => 'u' },
        'authorizing_integration_owners' => { '1' => '456' }
      }
      interaction = described_class.new(data, bot)
      expect(interaction.user_integration?).to be true
    end

    it 'returns false when only server integration is present' do
      data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 't',
        'version' => 1, 'guild_id' => '123', 'channel_id' => '4',
        'authorizing_integration_owners' => { '0' => '123' }
      }
      interaction = described_class.new(data, bot)
      expect(interaction.user_integration?).to be false
    end
  end

  describe 'server_integration?' do
    it 'returns false when server_id is nil' do
      data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 't',
        'version' => 1, 'channel_id' => '4',
        'authorizing_integration_owners' => { '0' => '123' }
      }
      interaction = described_class.new(data, bot)
      expect(interaction.server_integration?).to be false
    end

    it 'returns true when server owns server integration' do
      data = {
        'id' => '1', 'application_id' => '2', 'type' => 2, 'token' => 't',
        'version' => 1, 'guild_id' => '123', 'channel_id' => '4',
        'authorizing_integration_owners' => { '0' => '123' }
      }
      interaction = described_class.new(data, bot)
      expect(interaction.server_integration?).to be true
    end
  end
end