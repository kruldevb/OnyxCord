# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Paginator do
  context 'direction down' do
    it 'requests all pages until empty' do
      data = [
        [1, 2, 3],
        [4, 5],
        [],
        [6, 7]
      ]

      index = 0
      paginator = OnyxCord::Paginator.new(nil, :down) do |last_page|
        expect(last_page).to eq data[index - 1] if last_page
        next_page = data[index]
        index += 1
        next_page
      end

      expect(paginator.to_a).to eq [1, 2, 3, 4, 5]
    end
  end

  context 'direction up' do
    it 'requests all pages until empty' do
      data = [
        [6, 7],
        [4, 5],
        [],
        [1, 2, 3]
      ]

      index = 0
      paginator = OnyxCord::Paginator.new(nil, :up) do |last_page|
        expect(last_page).to eq data[index - 1] if last_page
        next_page = data[index]
        index += 1
        next_page
      end

      expect(paginator.to_a).to eq [7, 6, 5, 4]
    end
  end

  it 'only returns up to limit items' do
    data = [
      [1, 2, 3],
      [4, 5],
      []
    ]

    index = 0
    paginator = OnyxCord::Paginator.new(2, :down) do |_last_page|
      next_page = data[index]
      index += 1
      next_page
    end

    expect(paginator.to_a).to eq [1, 2]
  end

  describe 'enumerability' do
    let(:pages) { [[1, 2, 3], [4, 5], []] }
    let(:index) { [0] }
    let(:paginator) do
      OnyxCord::Paginator.new(nil, :down) do |_last|
        page = pages[index[0]]
        index[0] += 1
        page
      end
    end

    it 'returns an Enumerator when called without a block' do
      expect(paginator.each).to be_a(Enumerator)
    end

    it 'supports lazy enumeration' do
      result = paginator.lazy.map { |x| x * 2 }.first(3)
      expect(result).to eq [2, 4, 6]
    end

    it 'supports first' do
      expect(paginator.first).to eq 1
    end

    it 'supports take' do
      expect(paginator.take(4)).to eq [1, 2, 3, 4]
    end

    it 'supports find' do
      expect(paginator.find { |x| x == 4 }).to eq 4
    end

    it 'stops early when consumer breaks' do
      seen = []
      paginator.each { |x| seen << x; break if seen.size == 2 }
      expect(seen).to eq [1, 2]
    end

    it 'amount_fetched is updated incrementally' do
      paginator.each { |x| break if x == 2 }
      expect(paginator.amount_fetched).to eq 2
    end
  end

  describe 'enumeration reuse' do
    let(:pages) { [[1, 2, 3], [4, 5], []] }

    it 'cannot be reused after first to_a' do
      index = 0
      paginator = OnyxCord::Paginator.new(nil, :down) do |_last|
        page = pages[index]
        index += 1
        page
      end

      paginator.to_a
      expect { paginator.to_a }.to raise_error(OnyxCord::Paginator::InvalidStateError)
    end

    it 'does not duplicate items when iteration completes' do
      index = 0
      paginator = OnyxCord::Paginator.new(nil, :down) do |_last|
        page = pages[index]
        index += 1
        page
      end

      expect(paginator.to_a).to eq [1, 2, 3, 4, 5]
      expect(paginator.to_a).to eq [] rescue nil # second call raises
    end
  end

  describe 'regression detection' do
    it 'rejects repeated pages when nothing is consumed' do
      calls = 0
      paginator = OnyxCord::Paginator.new(nil, :down) do |_last|
        calls += 1
        calls > OnyxCord::Paginator::REPEATED_PAGE_LIMIT * 2 ? [] : [1, 2, 3]
      end

      expect { paginator.each { |_| } }.to raise_error(OnyxCord::Paginator::NoProgressError)
    end
  end

  describe 'argument validation' do
    it 'rejects nil block' do
      expect { OnyxCord::Paginator.new(nil, :down) }.to raise_error(ArgumentError)
    end

    it 'rejects unknown direction' do
      expect { OnyxCord::Paginator.new(nil, :sideways) }.to raise_error(ArgumentError)
    end

    it 'rejects negative limit' do
      expect do
        OnyxCord::Paginator.new(-1, :down) { [] }
      end.to raise_error(ArgumentError)
    end

    it 'accepts zero limit' do
      expect do
        OnyxCord::Paginator.new(0, :down) { [] }
      end.not_to raise_error
    end
  end
end