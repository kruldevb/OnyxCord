# frozen_string_literal: true

require 'onyxcord'

RSpec.describe OnyxCord::Profiler do
  describe '.configure' do
    it 'configures OnyxProfiler with default settings' do
      expect(OnyxProfiler).to receive(:configure).and_call_original
      described_class.configure
      expect(described_class.configured).to be true
    end
  end

  describe '.instrument' do
    before do
      described_class.configure
    end

    it 'instruments a block of code' do
      expect(OnyxProfiler).to receive(:instrument).with('test.operation').and_call_original
      result = described_class.instrument('test.operation') do
        42
      end
      expect(result).to eq(42)
    end

    it 'passes metadata to OnyxProfiler' do
      metadata = { key: 'value' }
      expect(OnyxProfiler).to receive(:instrument).with('test.operation', key: 'value').and_call_original
      described_class.instrument('test.operation', **metadata) do
        42
      end
    end
  end

  describe '.flush_to' do
    before do
      described_class.configure
    end

    it 'flushes events to the exporter' do
      expect(OnyxProfiler).to receive(:flush_to)
      described_class.flush_to
    end
  end

  describe '.flush' do
    before do
      described_class.configure
    end

    it 'flushes events from memory' do
      expect(OnyxProfiler).to receive(:flush)
      described_class.flush
    end
  end
end
