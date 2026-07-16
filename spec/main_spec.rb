# frozen_string_literal: true

require 'onyxcord'
require 'set'

class SimpleIDObject
  include OnyxCord::IDObject

  def initialize(id)
    @id = id
  end
end

describe OnyxCord do
  it 'should split messages correctly' do
    split = OnyxCord.split_message('a' * 5234)
    expect(split).to eq(['a' * 2000, 'a' * 2000, 'a' * 1234])

    split_on_space = OnyxCord.split_message("#{'a' * 1990} #{'b' * 2000}")
    expect(split_on_space).to eq(["#{'a' * 1990} ", 'b' * 2000])

    # regression test
    # there had been an issue where this would have raised an error,
    # and (if it hadn't raised) produced incorrect results
    split = OnyxCord.split_message("#{'a' * 800}\n" * 6)
    expect(split).to eq([
                          "#{'a' * 800}\n#{'a' * 800}\n",
                          "#{'a' * 800}\n#{'a' * 800}\n",
                          "#{'a' * 800}\n#{'a' * 800}"
                        ])

    large = OnyxCord.split_message("#{'x' * 100}\n" * 200)
    expect(large.all? { |chunk| chunk.length <= OnyxCord::CHARACTER_LIMIT }).to eq(true)
  end

  describe OnyxCord::IDObject do
    describe '#==' do
      it 'should match identical values' do
        ido = SimpleIDObject.new(123)
        expect(ido == SimpleIDObject.new(123)).to eq(true)
        expect(ido == 123).to eq(true)
        expect(ido == '123').to eq(true)
      end

      it 'should not match different values' do
        ido = SimpleIDObject.new(123)
        expect(ido == SimpleIDObject.new(124)).to eq(false)
        expect(ido == 124).to eq(false)
        expect(ido == '124').to eq(false)
      end
    end

    describe '#eql? and #hash' do
      it 'eql? returns true for two IDObjects with the same id' do
        a = SimpleIDObject.new(42)
        b = SimpleIDObject.new(42)
        expect(a.eql?(b)).to be true
      end

      it 'eql? returns false for objects with different ids' do
        a = SimpleIDObject.new(42)
        b = SimpleIDObject.new(43)
        expect(a.eql?(b)).to be false
      end

      it 'eql? returns false against non-IDObjects' do
        a = SimpleIDObject.new(42)
        expect(a.eql?(42)).to be false
        expect(a.eql?('42')).to be false
        expect(a.eql?(nil)).to be false
      end

      it 'hash returns id.hash so equal-by-id objects have same hash' do
        a = SimpleIDObject.new(42)
        b = SimpleIDObject.new(42)
        expect(a.hash).to eq(b.hash)
        expect(a.hash).to eq(42.hash)
      end

      it 'works as Hash key without conflicting with non-IDObject with same value' do
        a = SimpleIDObject.new(123)
        plan = { 123 => 'bare' }
        plan[a] = 'wrapped'
        plan['123'] = 'string'
        expect(plan.size).to eq 3
        expect(plan[a]).to eq 'wrapped'
      end

      it 'deduplicates in Set when equal' do
        set = Set.new
        set << SimpleIDObject.new(7)
        set << SimpleIDObject.new(7)
        set << SimpleIDObject.new(8)
        expect(set.size).to eq 2

        list = set.to_a
        expect(list.map(&:id).sort).to eq [7, 8]
      end
    end

    describe '#creation_time' do
      it 'should return the correct time' do
        ido = SimpleIDObject.new(175_928_847_299_117_063)
        time = Time.new(2016, 4, 30, 11, 18, 25.796, 0)
        expect(ido.creation_time.utc).to be_within(0.0001).of(time)
      end

      it 'rejects negative IDs' do
        ido = SimpleIDObject.new(-1)
        expect { ido.creation_time }.to raise_error(ArgumentError)
      end

      it 'respects snowflake validation in creation_time' do
        # happy path returns a time
        ok = SimpleIDObject.new(175_928_847_299_117_063)
        expect(ok.creation_time).to be_a(Time)

        # negative IDs are rejected
        bad = SimpleIDObject.new(-5)
        expect { bad.creation_time }.to raise_error(ArgumentError)
      end
    end

    describe '.synthesise' do
      it 'should match a precalculated time' do
        snowflake = 175_928_847_298_985_984
        time = Time.new(2016, 4, 30, 11, 18, 25.796, 0)
        expect(OnyxCord::IDObject.synthesise(time)).to eq(snowflake)
      end

      it 'should match #creation_time' do
        time = Time.new(2016, 4, 30, 11, 18, 25.796, 0)
        ido = SimpleIDObject.new(OnyxCord::IDObject.synthesise(time))
        expect(ido.creation_time).to be_within(0.0001).of(time)
      end

      it 'rejects non-Time argument' do
        expect { OnyxCord::IDObject.synthesise('not a time') }.to raise_error(ArgumentError)
      end

      it 'rejects time predating Discord epoch' do
        ancient = Time.utc(2010, 1, 1)
        expect { OnyxCord::IDObject.synthesise(ancient) }.to raise_error(ArgumentError)
      end
    end

    describe '.normalize_id' do
      it 'normalizes a positive Integer' do
        expect(OnyxCord::IDObject.normalize_id(5)).to eq 5
      end

      it 'normalizes a string with digits' do
        expect(OnyxCord::IDObject.normalize_id('5')).to eq 5
      end

      it 'rejects negatives' do
        expect { OnyxCord::IDObject.normalize_id(-1) }.to raise_error(ArgumentError)
      end

      it 'extracts id from IDObject' do
        obj = SimpleIDObject.new(42)
        expect(OnyxCord::IDObject.normalize_id(obj)).to eq 42
      end
    end
  end
end