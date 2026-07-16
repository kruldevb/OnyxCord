# frozen_string_literal: true

require 'onyxcord/utils/message_components'

describe OnyxCord::MessageComponents do
  describe '.payload' do
    it 'returns empty array for nil' do
      expect(described_class.payload(nil)).to eq []
    end

    it 'wraps a Hash into an array' do
      hash = { type: 10, content: 'x' }
      expect(described_class.payload(hash)).to eq [hash]
    end

    it 'maps an Array' do
      arr = [{ type: 10, content: 'a' }, { type: 1, components: [] }]
      expect(described_class.payload(arr)).to eq arr
    end

    it 'prefers #to_h over implicit Array-like via to_a for hashes' do
      struct = Struct.new(:type, :content).new(10, 'hello')
      expect(described_class.payload(struct)).to eq [{ type: 10, content: 'hello' }]
    end

    it 'uses to_a for Array-like' do
      obj = Class.new do
        def to_a
          [{ type: 10, content: 'x' }]
        end
      end.new
      expect(described_class.payload(obj)).to eq [{ type: 10, content: 'x' }]
    end

    it 'rejects random types' do
      expect { described_class.payload(42) }.to raise_error(ArgumentError)
    end
  end

  describe '.components_v2?' do
    it 'returns false for empty' do
      expect(described_class.components_v2?([])).to be false
    end

    it 'returns true for top-level V2 component' do
      expect(described_class.components_v2?([{ type: 10, content: 'x' }])).to be true
    end

    it 'returns true for nested V2 component' do
      tree = [{ type: 17, components: [{ type: 10, content: 'x' }] }]
      expect(described_class.components_v2?(tree)).to be true
    end

    it 'accepts string type 10' do
      expect(described_class.components_v2?([{ 'type' => '10', 'content' => 'x' }])).to be true
    end

    it 'rejects invalid string type' do
      expect do
        described_class.components_v2?([{ 'type' => '10abc', 'content' => 'x' }])
      end.to raise_error(ArgumentError)
    end

    it 'detects direct cycle' do
      a = { type: 1 }
      a[:components] = [a]
      expect { described_class.components_v2?([a]) }.to raise_error(ArgumentError, /Cycle/)
    end
  end

  describe '.flag_value' do
    it 'returns 0 for nil or :undef' do
      expect(described_class.flag_value(nil)).to eq 0
      expect(described_class.flag_value(:undef)).to eq 0
    end

    it 'returns integer for integer' do
      expect(described_class.flag_value(42)).to eq 42
    end

    it 'rejects negative integer' do
      expect { described_class.flag_value(-1) }.to raise_error(ArgumentError)
    end

    it 'returns integer for decimal string' do
      expect(described_class.flag_value('42')).to eq 42
    end

    it 'rejects invalid string' do
      expect { described_class.flag_value('abc') }.to raise_error(ArgumentError)
    end

    it 'rejects random object' do
      expect { described_class.flag_value(Object.new) }.to raise_error(ArgumentError)
    end

    it 'reduces an array of flags' do
      expect(described_class.flag_value([1, 2, 4])).to eq 7
    end

    it 'preserves unknown higher bits' do
      huge = 1 << 50
      expect(described_class.flag_value(huge)).to eq huge
    end

    it 'preserves existing flags when applying V2' do
      result = described_class.apply_v2_flag(4, [{ type: 10, content: 'x' }])
      expect(result).to eq 4 | OnyxCord::MessageComponents::IS_COMPONENTS_V2
    end

    it 'raises when applying V2 on top of unknown symbol' do
      expect do
        described_class.apply_v2_flag(:invalid_symbol, [{ type: 10, content: 'x' }])
      end.to raise_error(ArgumentError)
    end

    it 'accepts known symbols from MESSAGE_FLAG_BITS' do
      expect(described_class.flag_value(:is_components_v2)).to eq OnyxCord::MessageComponents::IS_COMPONENTS_V2
      expect(described_class.flag_value(:ephemeral)).to eq(1 << 6)
    end
  end
end