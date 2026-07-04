# frozen_string_literal: true

require 'onyxcord'

require 'spec_helper'

RSpec.describe OnyxCord::Interactions::PermissionBuilder do
  describe '#allow_role' do
    it 'adds an allowed role permission' do
      builder = described_class.new
      builder.allow_role(123_456)
      expect(builder.to_a).to eq([{ id: 123_456, type: 1, permission: true }])
    end
  end

  describe '#deny_role' do
    it 'adds a denied role permission' do
      builder = described_class.new
      builder.deny_role(123_456)
      expect(builder.to_a).to eq([{ id: 123_456, type: 1, permission: false }])
    end
  end

  describe '#allow_user' do
    it 'adds an allowed user permission' do
      builder = described_class.new
      builder.allow_user(789_012)
      expect(builder.to_a).to eq([{ id: 789_012, type: 2, permission: true }])
    end
  end

  describe '#deny_user' do
    it 'adds a denied user permission' do
      builder = described_class.new
      builder.deny_user(789_012)
      expect(builder.to_a).to eq([{ id: 789_012, type: 2, permission: false }])
    end
  end

  describe '#allow' do
    it 'raises for unknown types' do
      builder = described_class.new
      expect { builder.allow('invalid') }.to raise_error(ArgumentError, /unknown type/)
    end
  end

  describe '#deny' do
    it 'raises for unknown types' do
      builder = described_class.new
      expect { builder.deny('invalid') }.to raise_error(ArgumentError, /unknown type/)
    end
  end

  describe 'chaining' do
    it 'allows method chaining' do
      builder = described_class.new
      result = builder.allow_role(1).deny_role(2).allow_user(3)
      expect(result).to equal(builder)
      expect(builder.to_a.size).to eq(3)
    end
  end
end
