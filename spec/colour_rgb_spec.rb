# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::ColourRGB do
  describe '#initialize' do
    it 'accepts an Integer' do
      colour = described_class.new(0x7289da)
      expect(colour.combined).to eq 0x7289da
    end

    it 'accepts a hex string without # prefix' do
      colour = described_class.new('7289da')
      expect(colour.combined).to eq 0x7289da
    end

    it 'accepts a hex string with # prefix' do
      colour = described_class.new('#7289da')
      expect(colour.combined).to eq 0x7289da
    end

    it 'accepts a hex string with 0x prefix' do
      colour = described_class.new('0x7289da')
      expect(colour.combined).to eq 0x7289da
    end

    it 'extracts RGB components' do
      colour = described_class.new(0x7289da)
      expect(colour.red).to eq 0x72
      expect(colour.green).to eq 0x89
      expect(colour.blue).to eq 0xda
    end

    it 'rejects negative values' do
      expect { described_class.new(-1) }.to raise_error(ArgumentError, /between/)
    end

    it 'rejects values above 0xFFFFFF' do
      expect { described_class.new(0x1000000) }.to raise_error(ArgumentError, /between/)
    end

    it 'rejects invalid string' do
      expect { described_class.new('red') }.to raise_error(ArgumentError, /Invalid/)
    end

    it 'rejects invalid type' do
      expect { described_class.new(Object.new) }.to raise_error(ArgumentError, /Expected/)
    end

    it 'accepts 0 (black)' do
      colour = described_class.new(0)
      expect(colour.red).to eq 0
      expect(colour.green).to eq 0
      expect(colour.blue).to eq 0
    end

    it 'accepts 0xFFFFFF (white)' do
      colour = described_class.new(0xFFFFFF)
      expect(colour.red).to eq 255
      expect(colour.green).to eq 255
      expect(colour.blue).to eq 255
    end
  end

  describe '#hex' do
    it 'returns a six-digit lowercase hex string' do
      colour = described_class.new(0x7289da)
      expect(colour.hex).to eq '7289da'
    end

    it 'pads with leading zeros' do
      colour = described_class.new(0x00000f)
      expect(colour.hex).to eq '00000f'
    end
  end

  describe '#to_i' do
    it 'returns the combined integer' do
      colour = described_class.new(0x7289da)
      expect(colour.to_i).to eq 0x7289da
    end
  end

  describe '#to_s' do
    it 'returns a hex string with # prefix' do
      colour = described_class.new(0x7289da)
      expect(colour.to_s).to eq '#7289da'
    end
  end

  describe 'comparison' do
    it 'compares two ColourRGB objects' do
      a = described_class.new(0x7289da)
      b = described_class.new(0x7289da)
      c = described_class.new(0xffffff)
      expect(a == b).to be true
      expect(a == c).to be false
    end

    it 'compares against Integer' do
      a = described_class.new(0x7289da)
      expect(a == 0x7289da).to be true
      expect(a == 0xffffff).to be false
    end
  end

  describe '#eql? and #hash' do
    it 'two equal objects have same hash' do
      a = described_class.new(0x7289da)
      b = described_class.new(0x7289da)
      expect(a.eql?(b)).to be true
      expect(a.hash).to eq(b.hash)
    end

    it 'different objects have different hash' do
      a = described_class.new(0x7289da)
      b = described_class.new(0xffffff)
      expect(a.hash).not_to eq(b.hash)
    end

    it 'works as Hash key' do
      h = {}
      h[described_class.new(0x7289da)] = 'discord'
      h[described_class.new(0x7289da)] = 'discord2'
      expect(h.size).to eq 1
    end
  end
end
