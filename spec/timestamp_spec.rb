# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::TimestampMarkdown do
  describe '#initialize and #style' do
    it 'defaults to short_datetime style' do
      ts = described_class.new(Time.now, nil)
      expect(ts.style).to eq 'f'
    end

    it 'accepts canonical symbol' do
      ts = described_class.new(Time.now, :relative)
      expect(ts.style).to eq 'R'
    end

    it 'accepts single-char specifier' do
      ts = described_class.new(Time.now, 'T')
      expect(ts.style).to eq 'T'
    end

    it 'rejects unknown symbol' do
      expect { described_class.new(Time.now, :invalid) }.to raise_error(ArgumentError)
    end

    it 'rejects unknown string specifier' do
      expect { described_class.new(Time.now, 'X') }.to raise_error(ArgumentError)
    end

    it 'rejects numeric style' do
      expect { described_class.new(Time.now, 42) }.to raise_error(ArgumentError)
    end
  end

  describe '#style_name' do
    it 'returns the canonical symbol' do
      ts = described_class.new(Time.now, :relative)
      expect(ts.style_name).to eq :relative
    end
  end

  describe '#to_s' do
    it 'produces a Discord-formatted timestamp' do
      ts = described_class.new(Time.now, :short_time)
      result = ts.to_s
      expect(result).to match(/\A<t:\d+:t>\z/)
    end
  end

  describe 'style predicates' do
    %i[short_time long_time short_date long_date short_datetime long_datetime relative simple_datetime medium_datetime].each do |name|
      it "responds to #{name}?" do
        ts = described_class.new(Time.now, name)
        expect(ts.send(:"#{name}?")).to be true
      end
    end

    it 'returns false for non-matching style' do
      ts = described_class.new(Time.now, :relative)
      expect(ts.short_time?).to be false
    end
  end

  describe 'STYLES and TIMESTAMP_STYLES consistency' do
    it 'has the same keys as OnyxCord::TIMESTAMP_STYLES' do
      expect(described_class::STYLES.keys.sort).to eq OnyxCord::TIMESTAMP_STYLES.keys.sort
    end

    it 'has the same values as OnyxCord::TIMESTAMP_STYLES' do
      expect(described_class::STYLES.values.sort).to eq OnyxCord::TIMESTAMP_STYLES.values.sort
    end

    it 'every predicate corresponds to a style' do
      described_class::STYLES.each do |name, code|
        ts = described_class.new(Time.now, name)
        expect(ts.send(:"#{name}?")).to be true
        expect(ts.style).to eq code
      end
    end
  end
end
