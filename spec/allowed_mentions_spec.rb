# frozen_string_literal: true

require 'onyxcord/internal/message_payload'
require 'onyxcord/utils/allowed_mentions'

describe OnyxCord::AllowedMentions do
  it 'has disnake-style none and all helpers' do
    expect(described_class.none.to_hash).to eq(parse: [], users: [], roles: [], replied_user: false)
    expect(described_class.all.to_hash).to eq(parse: %w[users roles everyone], replied_user: true)
  end

  describe 'validation' do
    it 'accepts valid parse values' do
      m = described_class.new(parse: %w[users roles])
      expect(m.parse).to eq %w[users roles]
    end

    it 'rejects unknown parse values' do
      expect { described_class.new(parse: %w[nosuch]) }.to raise_error(ArgumentError)
    end

    it 'accepts up to 100 user IDs' do
      ids = (1..100).map { |id| id.to_s.rjust(17, '0') }
      m = described_class.new(users: ids)
      expect(m.users.size).to eq 100
    end

    it 'rejects more than 100 user IDs' do
      ids = (1..101).map { |id| id.to_s.rjust(17, '0') }
      expect { described_class.new(users: ids) }.to raise_error(ArgumentError, /100/)
    end

    it 'rejects more than 100 role IDs' do
      ids = (1..101).map { |id| id.to_s.rjust(17, '0') }
      expect { described_class.new(roles: ids) }.to raise_error(ArgumentError, /100/)
    end

    it 'deduplicates IDs' do
      m = described_class.new(users: %w[12345678901234567 12345678901234567 23456789012345678])
      expect(m.users).to eq %w[12345678901234567 23456789012345678]
    end

    it 'rejects non-snowflake IDs' do
      expect { described_class.new(users: ['abc']) }.to raise_error(ArgumentError)
    end

    it 'rejects invalid parse type' do
      expect { described_class.new(parse: 42) }.to raise_error(ArgumentError)
    end

    it 'rejects parse "users" combined with explicit users' do
      expect do
        described_class.new(parse: %w[users], users: %w[123456789012345678])
      end.to raise_error(ArgumentError, /combine/)
    end

    it 'rejects parse "roles" combined with explicit roles' do
      expect do
        described_class.new(parse: %w[roles], roles: %w[123456789012345678])
      end.to raise_error(ArgumentError, /combine/)
    end

    it 'normalizes IDObjects to their ids in to_hash' do
      obj = Class.new do
        include OnyxCord::IDObject
        attr_reader :id

        def initialize(id)
          @id = id
        end
      end.new(123_456_789_012_345_678)
      m = described_class.new(users: [obj])
      hash = m.to_hash
      expect(hash[:users]).to eq %w[123456789012345678]
    end

    it 'normalizes integers to string representation' do
      m = described_class.new(users: [123_456_789_012_345_678])
      expect(m.to_hash[:users]).to eq %w[123456789012345678]
    end

    it 'replied_user defaults to nil and accepts boolean' do
      m = described_class.new
      expect(m.replied_user).to be_nil
      m.replied_user = true
      expect(m.replied_user).to be true
    end

    it 'copies arrays on assignment to prevent external mutation' do
      external = %w[12345678901234567 23456789012345678]
      m = described_class.new(users: external)
      external << '34567890123456789'
      expect(m.users.size).to eq 2
    end

    it 'to_hash returns new arrays, independent of stored ones' do
      m = described_class.none
      hash = m.to_hash
      expect(hash[:parse]).to be_a(Array)
      hash[:parse] << 'users'
      expect(m.to_hash[:parse]).to eq []
    end
  end
end