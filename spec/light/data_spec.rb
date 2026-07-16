# frozen_string_literal: true

require 'onyxcord'

RSpec.describe OnyxCord::Light::LightProfile do
  BOT = OnyxCord::Light::LightBot.new('Bot dummy.abc.def', token_type: :bot)

  let(:full_payload) do
    {
      'id' => '123456789012345678',
      'username' => 'testuser',
      'global_name' => 'Test User',
      'discriminator' => '0001',
      'avatar' => 'abc123def456',
      'bot' => true,
      'public_flags' => 0,
      'banner' => 'ban_hash_001',
      'accent_color' => 0x1a2b3c,
      'locale' => 'en-US',
      'avatar_decoration_data' => { 'asset' => 'decoration_hash' },
      'collectibles' => { 'items' => [] },
      'primary_guild' => { 'id' => '111' },
      'email' => 'test@example.com',
      'verified' => true,
      'system' => false,
      '_webhook' => false
    }
  end

  let(:minimal_payload) do
    {
      'id' => '999',
      'username' => 'minimal',
      'discriminator' => '0'
    }
  end

  describe 'with full payload' do
    subject(:profile) { described_class.new(full_payload, BOT) }

    it { expect(profile.id).to eq(123_456_789_012_345_678) }
    it { expect(profile.username).to eq('testuser') }
    it { expect(profile.global_name).to eq('Test User') }
    it { expect(profile.display_name).to eq('Test User') }
    it { expect(profile.discriminator).to eq('0001') }
    it { expect(profile.avatar_id).to eq('abc123def456') }
    it { expect(profile.bot_account?).to be true }
    it { expect(profile.system_account?).to be false }
    it { expect(profile.webhook?).to be false }
    it { expect(profile.public_flags).to eq(0) }
    it { expect(profile.staff?).to be false }
    it { expect(profile.partner?).to be false }
    it { expect(profile.email).to eq('test@example.com') }
    it { expect(profile.verified).to be true }
    it { expect(profile.email_scope?).to be true }
    it { expect(profile.locale).to eq('en-US') }
    it { expect(profile.accent_color).to eq(0x1a2b3c) }

    it 'has banner_id from the payload' do
      expect(profile.instance_variable_get(:@banner_id)).to eq('ban_hash_001')
    end

    it 'banner_url uses payload data only' do
      expect(profile.banner_url).to include('ban_hash_001')
    end

    it 'avatar_decoration_data is present' do
      expect(profile.avatar_decoration_data).to eq('asset' => 'decoration_hash')
    end

    it 'avatar_decoration_id extracts the asset hash' do
      expect(profile.avatar_decoration_id).to eq('decoration_hash')
    end

    it 'collectibles is present' do
      expect(profile.collectibles).to eq('items' => [])
    end

    it 'primary_guild is present' do
      expect(profile.primary_guild).to eq('id' => '111')
    end

    it 'mention returns proper format' do
      expect(profile.mention).to eq("<@#{profile.id}>")
    end

    it 'avatar_url uses avatar_id' do
      expect(profile.avatar_url).to include('abc123def456')
    end

    it 'default avatar_url when no avatar set' do
      p = described_class.new({ 'id' => '100', 'username' => 'nopic', 'discriminator' => '0' }, BOT)
      expect(p.avatar_url).to include('embed/avatars')
    end

    it 'round-trip distinct includes username' do
      expect(profile.distinct).to include('testuser')
    end

    it 'inspect contains id and username' do
      s = profile.inspect
      expect(s).to include('testuser')
      expect(s).to include(profile.id.to_s)
    end

    it 'supports equality by id' do
      other = described_class.new({ 'id' => '123456789012345678', 'username' => 'z' }, BOT)
      expect(profile).to eq(other)
      expect(profile).to eql(other)
    end

    it 'supports creation_time' do
      expect(profile.creation_time).to be_a(Time)
    end
  end

  describe 'with minimal payload' do
    subject(:profile) { described_class.new(minimal_payload, BOT) }

    it { expect(profile.id).to eq(999) }
    it { expect(profile.username).to eq('minimal') }
    it { expect(profile.display_name).to eq('minimal') }
    it { expect(profile.global_name).to be_nil }
    it { expect(profile.bot_account?).to be false }
    it { expect(profile.system_account?).to be_nil }
    it { expect(profile.webhook?).to be false }
    it { expect(profile.public_flags).to eq(0) }
    it { expect(profile.staff?).to be false }
    it { expect(profile.email).to be_nil }
    it { expect(profile.verified).to be_nil }
    it { expect(profile.email_scope?).to be false }
    it { expect(profile.locale).to be_nil }
    it { expect(profile.accent_color).to be_nil }
    it { expect(profile.banner_url).to be_nil }
    it { expect(profile.avatar_decoration_url).to be_nil }
    it { expect(profile.avatar_decoration_data).to be_nil }
    it { expect(profile.avatar_decoration_id).to be_nil }
    it { expect(profile.collectibles).to be_nil }
    it { expect(profile.primary_guild).to be_nil }
  end

  describe 'schema validation (LIGHT-0104)' do
    it 'rejects payload without id' do
      expect { described_class.new({ 'username' => 'x' }, BOT) }
        .to raise_error(ArgumentError, /Missing 'id'/)
    end

    it 'rejects payload without username' do
      expect { described_class.new({ 'id' => '1' }, BOT) }
        .to raise_error(ArgumentError, /missing required field 'username'/i)
    end
  end
end

RSpec.describe OnyxCord::Light::LightServer do
  BOT = OnyxCord::Light::LightBot.new('Bot dummy.abc.def', token_type: :bot)

  let(:payload) do
    {
      'id' => '987654321',
      'name' => 'Test Server',
      'icon' => 'server_icon_hash',
      'owner' => true,
      'permissions' => 8
    }
  end

  subject(:server) { described_class.new(payload, BOT) }

  it { expect(server.id).to eq(987_654_321) }
  it { expect(server.name).to eq('Test Server') }
  it { expect(server.icon_id).to eq('server_icon_hash') }
  it { expect(server.icon_url).to include('server_icon_hash') }
it { expect(server.link).to include(server.id.to_s) }
    it { expect(server.bot_is_owner?).to be true }
  it { expect(server.bot_permissions).to be_a(OnyxCord::Permissions) }
  it { expect(server.bot_permissions.administrator).to be true }

  it 'handles missing permissions gracefully' do
    s = described_class.new({ 'id' => '1', 'name' => 'x', 'owner' => false }, BOT)
    expect(s.bot_permissions).to be_a(OnyxCord::Permissions)
    expect(s.bot_permissions.bits).to eq(0)
  end

  it 'UltraLightServer also validates id' do
    expect { OnyxCord::Light::UltraLightServer.new({ 'name' => 'x' }, BOT) }
      .to raise_error(ArgumentError, /Missing 'id'/)
  end
end