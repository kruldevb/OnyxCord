# frozen_string_literal: true

require 'onyxcord'

RSpec.describe OnyxCord::Light::LightBot do
  SENTINEL = 'SECRET_TOKEN_abc.def.ghi'

  describe '.new / Credential' do
    it 'accepts a bot token with token_type: :bot' do
      bot = described_class.new(SENTINEL, token_type: :bot)
      expect(bot.credential.type).to eq(:bot)
      expect(bot._authorization).to eq("Bot #{SENTINEL}")
      expect(bot.credential.supports?).to be true
    end

    it 'accepts a Bearer token with token_type: :bearer' do
      bot = described_class.new(SENTINEL, token_type: :bearer)
      expect(bot.credential.type).to eq(:bearer)
      expect(bot._authorization).to eq("Bearer #{SENTINEL}")
      expect(bot.credential.supports?).to be false
    end

    it 'accepts a prefixed Bot token without token_type' do
      bot = described_class.new("Bot #{SENTINEL}")
      expect(bot.credential.type).to eq(:bot)
      expect(bot._authorization).to eq("Bot #{SENTINEL}")
    end

    it 'accepts a prefixed Bearer token without token_type' do
      bot = described_class.new("Bearer #{SENTINEL}")
      expect(bot.credential.type).to eq(:bearer)
      expect(bot._authorization).to eq("Bearer #{SENTINEL}")
    end

    it 'accepts an OAuth2 token object and preserves scopes' do
      obj = Struct.new(:token, :scope).new(SENTINEL, 'identify guilds')
      bot = described_class.new(obj, token_type: :bearer)
      expect(bot.credential.type).to eq(:bearer)
      expect(bot._authorization).to eq("Bearer #{SENTINEL}")
      expect(bot.credential.scopes).to eq(%i[identify guilds])
    end

    it 'accepts scopes as Array of Symbols in the constructor' do
      bot = described_class.new(SENTINEL, token_type: :bearer, scopes: %i[identify guilds connections])
      expect(bot.credential.scopes).to eq(%i[identify guilds connections])
    end

    it 'accepts scopes as space-separated String' do
      bot = described_class.new(SENTINEL, token_type: :bearer, scopes: 'identify guilds')
      expect(bot.credential.scopes).to eq(%i[identify guilds])
    end

    it 'rejects empty token' do
      expect { described_class.new('') }.to raise_error(ArgumentError, /nil or empty/)
    end

    it 'rejects nil token' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /nil or empty/)
    end

    it 'rejects invalid token_type' do
      expect { described_class.new('x', token_type: :user) }
        .to raise_error(ArgumentError, /invalid token_type/)
    end

    context 'raw user account token (unprefixed, no token_type)' do
      it 'rejects with UserTokenRejected' do
        expect { described_class.new('abc123') }
          .to raise_error(OnyxCord::Light::UserTokenRejected, /token_type:/)
      end
    end
  end

  describe '#inspect / token redaction (LIGHT-0004)' do
    it 'never contains the sentinel token' do
      bot = described_class.new(SENTINEL, token_type: :bot)
      expect(bot.inspect).not_to include(SENTINEL)
      expect(bot.inspect).to include('[redacted')
      expect(bot.inspect).to include('LightBot')
    end

    it 'credential inspect also redacts the token' do
      cred = described_class.new(SENTINEL, token_type: :bot).credential
      expect(cred.to_s).not_to include(SENTINEL)
      expect(cred.to_s).to include('[redacted')
      expect(cred.inspect).to eq(cred.to_s)
    end

    it '_authorization is available but separate from inspect' do
      bot = described_class.new(SENTINEL, token_type: :bot)
      expect(bot._authorization).to include(SENTINEL)
      expect(bot.inspect).not_to include(SENTINEL)
    end
  end

  describe 'MissingScopeError (LIGHT-0103)' do
    it 'raises when a required scope is missing' do
      bot = described_class.new(SENTINEL, token_type: :bearer, scopes: %i[identify])
      expect { bot.credential.require_scope!(:guilds) }
        .to raise_error(OnyxCord::Light::MissingScopeError, /guilds/)
    end

    it 'does not raise when scopes are not declared (nil)' do
      bot = described_class.new(SENTINEL, token_type: :bearer)
      expect { bot.credential.require_scope!(:anything) }.not_to raise_error
    end

    it 'does not raise when the scope is present' do
      bot = described_class.new(SENTINEL, token_type: :bearer, scopes: %i[identify guilds])
      expect { bot.credential.require_scope!(:guilds) }.not_to raise_error
    end

    it 'MissingScopeError exposes :scope and :present_scopes on error' do
      cred = described_class.new(SENTINEL, token_type: :bearer, scopes: %i[identify]).credential
      begin
        cred.require_scope!(:connections)
      rescue OnyxCord::Light::MissingScopeError => e
        expect(e.scope).to eq(:connections)
        expect(e.present_scopes).to eq(%i[identify])
      end
    end
  end

  describe 'Credential.normalize_scopes' do
    it 'returns nil for nil' do
      expect(OnyxCord::Light::Credential.normalize_scopes(nil)).to be_nil
    end

    it 'converts array to frozen symbols' do
      expect(OnyxCord::Light::Credential.normalize_scopes(%w[identify guilds]))
        .to eq(%i[identify guilds])
    end

    it 'splits space-separated string' do
      expect(OnyxCord::Light::Credential.normalize_scopes('identify guilds connections'))
        .to eq(%i[identify guilds connections])
    end
  end
end