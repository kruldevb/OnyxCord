# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Configuration do
  describe OnyxCord::Configuration::CacheSizes do
    subject(:sizes) { described_class.new }

    it 'has default values' do
      expect(sizes.servers).to eq(1000)
      expect(sizes.channels).to eq(10_000)
      expect(sizes.users).to eq(50_000)
      expect(sizes.pm_channels).to eq(1000)
      expect(sizes.thread_members).to eq(5000)
      expect(sizes.server_previews).to eq(100)
    end

    it 'rejects negative values' do
      expect { sizes.servers = -1 }.to raise_error(ArgumentError, /non-negative/)
    end

    it 'rejects non-integer values' do
      expect { sizes.servers = 'abc' }.to raise_error(ArgumentError, /Integer/)
    end

    it 'accepts nil values' do
      sizes.servers = nil
      expect(sizes.servers).to be_nil
    end

    it 'rejects values exceeding max' do
      expect { sizes.servers = 2_000_000 }.to raise_error(ArgumentError, /exceeds maximum/)
    end

    it 'accepts valid values' do
      sizes.users = 100
      expect(sizes.users).to eq(100)
    end

    it 'raises on unknown keys for []' do
      expect { sizes[:unknown] }.to raise_error(ArgumentError, /Unknown CacheSizes key/)
    end

    it 'raises on unknown keys for []=' do
      expect { sizes[:unknown] = 100 }.to raise_error(ArgumentError, /Unknown CacheSizes key/)
    end

    it 'converts to hash' do
      h = sizes.to_h
      expect(h).to be_a(Hash)
      expect(h[:servers]).to eq(1000)
      expect(h.keys.length).to eq(6)
    end

    it 'duplicates correctly' do
      copy = sizes.dup
      copy.servers = 999
      expect(sizes.servers).to eq(1000)
      expect(copy.servers).to eq(999)
    end
  end

  describe '#normalize_cache' do
    it 'accepts valid preset symbols' do
      expect(subject.normalize_cache(:minimal)).to eq(OnyxCord::Configuration::CACHE_PRESETS[:minimal])
    end

    it 'raises on unknown presets' do
      expect { subject.normalize_cache(:invalid) }.to raise_error(ArgumentError, /Unknown cache preset/)
    end

    it 'raises on unknown hash keys' do
      expect { subject.normalize_cache(users: true, unknown_key: true) }.to raise_error(ArgumentError, /Unknown cache keys/)
    end

    it 'accepts valid hash keys' do
      result = subject.normalize_cache(users: true)
      expect(result[:users]).to be true
    end
  end

  describe '#normalize_event_workers' do
    it 'raises on zero' do
      expect { subject.normalize_event_workers(0) }.to raise_error(ArgumentError, /greater than zero/)
    end

    it 'raises on negative' do
      expect { subject.normalize_event_workers(-1) }.to raise_error(ArgumentError, /greater than zero/)
    end

    it 'accepts positive integers' do
      expect(subject.normalize_event_workers(8)).to eq(8)
    end
  end

  describe '#normalize_event_queue_size' do
    it 'accepts nil' do
      expect(subject.normalize_event_queue_size(nil)).to be_nil
    end

    it 'raises on zero' do
      expect { subject.normalize_event_queue_size(0) }.to raise_error(ArgumentError, /greater than zero/)
    end

    it 'accepts positive integers' do
      expect(subject.normalize_event_queue_size(100)).to eq(100)
    end
  end
end
