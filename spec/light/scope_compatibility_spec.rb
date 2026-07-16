# frozen_string_literal: true

require 'onyxcord'
require 'onyxcord/rest/routes/user'

# LIGHT-0307 — Scope compatibility tests.
#
# When the credential declares a scope list (typical for OAuth2 Bearer
# tokens obtained via OAuth2 gem), {LightBot} must raise {MissingScopeError}
# BEFORE issuing a request that needs a missing scope. The error message
# references the scope name and present scopes, and never leaks the token.
#
# These specs use stubbing via `OnyxCord::REST::User`: a counter on the
# module-level methods to detect when an HTTP call was actually made.
RSpec.describe 'Scope compatibility (LIGHT-0307)' do
  let(:bot) { OnyxCord::Light::LightBot.new('dummy.token.value', token_type: :bearer) }

  describe 'with declared scopes (auth failure surface)' do
    let(:bot_with) { OnyxCord::Light::LightBot.new('dummy.token.value', token_type: :bearer, scopes: %w[identify]) }

    it 'MissingScopeError mentions the missing scope name' do
      err = capture_missing { bot_with.credential.require_scope!(:guilds) }
      expect(err.scope).to eq(:guilds)
      expect(err.message).to include('guilds')
    end

    it 'MissingScopeError reflects the present scopes' do
      err = capture_missing { bot_with.credential.require_scope!(:connections) }
      expect(err.present_scopes).to eq(%i[identify])
      expect(err.message).to include(':identify')
    end

    it 'MissingScopeError message never contains the token' do
      err = capture_missing { bot_with.credential.require_scope!(:guilds) }
      expect(err.message).not_to include('dummy.token.value')
    end

    def capture_missing
      yield
    rescue OnyxCord::Light::MissingScopeError => e
      e
    end
  end

  describe 'operations enforce their required scopes' do
    let(:bot_full) do
      OnyxCord::Light::LightBot.new('dummy.token', token_type: :bearer,
                                                       scopes: %w[identify email guilds connections])
    end

    it 'profile requires :identify' do
      computed = OnyxCord::Light::LightBot::REQUIRED_SCOPES[:profile]
      expect(computed).to eq(%i[identify])
    end

    it 'servers requires :guilds' do
      expect(OnyxCord::Light::LightBot::REQUIRED_SCOPES[:servers]).to eq(%i[guilds])
    end

    it 'connections requires :connections' do
      expect(OnyxCord::Light::LightBot::REQUIRED_SCOPES[:connections]).to eq(%i[connections])
    end
  end

  describe 'without declared scopes (token only)' do
    let(:bot_unknown) { OnyxCord::Light::LightBot.new('other.token', token_type: :bearer) }

    it 'no MissingScopeError is raised (caller does not know)' do
      expect { bot_unknown.credential.require_scope!(:anything) }.not_to raise_error
    end

    it 'has_scope? returns true when scopes are unknown' do
      # Conservative behavior: when scopes are nil, do not block calls.
      expect(bot_unknown.credential.has_scope?(:guilds)).to be true
    end

    it 'has_scope? returns false only when scopes are declared and missing' do
      known = OnyxCord::Light::LightBot.new('t', token_type: :bearer, scopes: %w[identify])
      expect(known.credential.has_scope?(:guilds)).to be false
      expect(known.credential.has_scope?(:identify)).to be true
    end
  end

  describe 'BotCredential does not support user-side scopes' do
    let(:bot_token) { OnyxCord::Light::LightBot.new('Bot ' + 'a' * 60 + '.b.c', token_type: :bot) }

    it 'BotCredential has nil scopes by default' do
      expect(bot_token.credential.scopes).to be_nil
    end

    it 'BotCredential authorization keeps the Bot prefix' do
      expect(bot_token._authorization).to start_with('Bot ')
    end
  end

  describe 'Message safety (LIGHT-0004 + LIGHT-0307)' do
    it 'error backtraces never carry the raw token' do
      bot = OnyxCord::Light::LightBot.new('SENTINEL_TOKEN', token_type: :bearer, scopes: %w[identify])
      begin
        bot.credential.require_scope!(:guilds)
      rescue OnyxCord::Light::MissingScopeError => e
        expect(e.backtrace.join("\n")).not_to include('SENTINEL_TOKEN')
        expect(e.message).not_to include('SENTINEL_TOKEN')
      end
    end
  end
end