# frozen_string_literal: true

require 'onyxcord'

RSpec.describe OnyxCord::Light::Connection do
  BOT = OnyxCord::Light::LightBot.new('Bot dummy.abc.def', token_type: :bot)

  let(:full_payload) do
    {
      'type' => 'twitch',
      'name' => 'twitch_user',
      'id' => 'ext_123',
      'revoked' => false,
      'verified' => true,
      'friend_sync' => true,
      'show_activity' => true,
      'two_way_link' => true,
      'visibility' => 1,
      'integrations' => [
        {
          'id' => '999',
          'type' => 'twitch',
          'guild' => { 'id' => '200', 'name' => 'SubGuild' },
          'account' => { 'id' => 'own_1', 'name' => 'Owner', 'type' => 'twitch' }
        }
      ]
    }
  end

  describe 'with full payload' do
    subject(:conn) { described_class.new(full_payload, BOT) }

    it 'stores type as frozen String, not Symbol' do
      expect(conn.type).to eq('twitch')
      expect(conn.type).to be_frozen
      expect(conn.type).not_to be_a(Symbol)
    end

    it 'exposes optional type_sym for known types' do
      expect(conn.type_sym).to eq(:twitch)
    end

    it 'returns nil type_sym for unknown types' do
      c = described_class.new({ 'type' => 'unknown_service', 'name' => 'x', 'id' => 'x' }, BOT)
      expect(c.type).to eq('unknown_service')
      expect(c.type_sym).to be_nil
    end

    it 'exposes all Connection fields' do
      expect(conn.name).to eq('twitch_user')
      expect(conn.id).to eq('ext_123')
      expect(conn.revoked?).to be false
      expect(conn.verified?).to be true
      expect(conn.friend_sync?).to be true
      expect(conn.show_activity?).to be true
      expect(conn.two_way_link?).to be true
      expect(conn.visibility).to eq(1)
    end

    it 'has frozen integrations array' do
      expect(conn.integrations).to be_frozen
      expect(conn.integrations.length).to eq(1)
    end

    it 'integration has server and server_account' do
      int = conn.integrations.first
      expect(int.id).to eq(999)
      expect(int.server).to be_a(OnyxCord::Light::UltraLightServer)
      expect(int.server.name).to eq('SubGuild')
      expect(int.server_account).to be_a(OnyxCord::Light::IntegrationAccount)
      expect(int.server_account.name).to eq('Owner')
      expect(int.server_account.id).to eq('own_1')
      expect(int.server_account.type).to eq('twitch')
    end

    it 'IntegrationAccount has inspect' do
      expect(conn.integrations.first.server_account.to_s).to include('twitch')
    end

    it 'KNN_CONNECTION_TYPES covers multiple services' do
      %w[twitch youtube github steam spotify reddit xbox].each do |name|
        expect(OnyxCord::Light::KNOWN_CONNECTION_TYPES[name]).to be_a(Symbol)
      end
    end
  end

  describe 'with missing integrations (LIGHT-0105)' do
    let(:minimal_payload) { { 'type' => 'youtube', 'name' => 'yt_user', 'id' => 'yt_1' } }

    subject(:conn) { described_class.new(minimal_payload, BOT) }

    it 'returns frozen empty array when integrations field is missing' do
      expect(conn.integrations).to eq([])
      expect(conn.integrations).to be_frozen
    end

    it 'booleans are nil when absent (unknown)' do
      expect(conn.revoked).to be_nil
      expect(conn.verified).to be_nil
      expect(conn.friend_sync).to be_nil
      expect(conn.show_activity).to be_nil
      expect(conn.two_way_link).to be_nil
    end
  end

  describe 'Integration without guild' do
    it 'server is nil when guild field is absent or empty' do
      c = described_class.new({
                                'type' => 'twitch', 'name' => 'x', 'id' => 'x',
                                'integrations' => [
                                  { 'id' => '50', 'type' => 'twitch',
                                    'account' => { 'id' => 'a1', 'name' => 'A' } }
                                ]
                              }, BOT)
      int = c.integrations.first
      expect(int.server).to be_nil
      expect(int.server_account).to be_a(OnyxCord::Light::IntegrationAccount)
    end
  end

  describe 'Integration immutability (LIGHT-0110)' do
    it 'cannot mutate integrations array' do
      conn = described_class.new(full_payload, BOT)
      expect { conn.integrations << double }.to raise_error(FrozenError)
    end
  end

  describe 'Integration type Safety (LIGHT-0107, LIGHT-0108)' do
    it 'never creates Symbols from untrusted type strings' do
      expect(OnyxCord::Light::KNOWN_CONNECTION_TYPES.values).to all(be_a(Symbol))
      expect(OnyxCord::Light::KNOWN_CONNECTION_TYPES.keys).to all(be_frozen)
    end

    it 'unknown type preserved as String without creating a Symbol' do
      c = described_class.new({ 'type' => 'new_service_v42', 'name' => 'x', 'id' => 'x' }, BOT)
      expect(Symbol.all_symbols.map(&:to_s)).not_to include('new_service_v42')
    end
  end
end