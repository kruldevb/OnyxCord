# frozen_string_literal: true

require 'onyxcord'

# alias so I don't have to type it out every time...
BUCKET = OnyxCord::Commands::Bucket
RATELIMITER = OnyxCord::Commands::RateLimiter

# Fake clock for deterministic testing of monotonic-clock-based rate limiter
class FakeClock
  attr_accessor :time

  def initialize(start = 100.0)
    @time = start
  end

  def now
    @time
  end

  def advance(seconds)
    @time += seconds
  end
end

describe OnyxCord::Commands::Bucket do
  describe 'rate_limited?' do
    it 'should not rate limit one request' do
      expect(BUCKET.new(1, 5, 2).rate_limited?(:a)).to be_falsy
      expect(BUCKET.new(nil, nil, 2).rate_limited?(:a)).to be_falsy
      expect(BUCKET.new(1, 5, nil).rate_limited?(:a)).to be_falsy
    end

    it 'should fail to initialize with invalid arguments' do
      expect { BUCKET.new(0, nil, 0) }.to raise_error(ArgumentError)
      expect { BUCKET.new(0, 1, nil) }.to raise_error(ArgumentError, /positive/)
      expect { BUCKET.new(nil, nil, -1) }.to raise_error(ArgumentError, /non-negative/)
    end

    it 'should fail to rate limit something invalid' do
      expect { BUCKET.new(1, 5, 2).rate_limited?("can't RL a string!") }.to raise_error(ArgumentError)
    end

    it 'should rate limit one request over the limit' do
      b = BUCKET.new(1, 5, nil)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should rate limit multiple requests that are over the limit' do
      b = BUCKET.new(3, 5, nil)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should allow to be passed a custom increment' do
      b = BUCKET.new(5, 5, nil)
      expect(b.rate_limited?(:a, increment: 2)).to be_falsy
      expect(b.rate_limited?(:a, increment: 2)).to be_falsy
      expect(b.rate_limited?(:a, increment: 2)).to be_truthy
    end

    it 'should not rate limit after the limit ran out' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(2, 5, nil, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(4)
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(1)
      expect(b.rate_limited?(:a)).to be_falsy
    end

    it 'should reset the limit after it ran out' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(2, 5, nil, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(5)
      expect(b.rate_limited?(:a)).to be_falsy
      clock.advance(0.01)
      expect(b.rate_limited?(:a)).to be_falsy
      clock.advance(0.01)
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should rate limit based on delay' do
      b = BUCKET.new(nil, nil, 2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should not rate limit after the delay ran out' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(nil, nil, 2, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should rate limit based on both limit and delay' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(2, 5, 2, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(2)
      expect(b.rate_limited?(:a)).to be_truthy
      clock.advance(1)
      expect(b.rate_limited?(:a)).to be_falsy
      clock.advance(1)
      expect(b.rate_limited?(:a)).to be_truthy

      clock2 = FakeClock.new(200.0)
      b2 = BUCKET.new(2, 5, 2, clock: clock2)
      expect(b2.rate_limited?(:a)).to be_falsy
      expect(b2.rate_limited?(:a)).to be_truthy
      clock2.advance(4)
      expect(b2.rate_limited?(:a)).to be_falsy
      expect(b2.rate_limited?(:a)).to be_truthy
      clock2.advance(1)
      expect(b2.rate_limited?(:a)).to be_truthy
    end

    it 'should return correct times' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(2, 5, 2, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a).round(2)).to eq(2)
      clock.advance(1)
      expect(b.rate_limited?(:a).round(2)).to eq(1)
      clock.advance(1.01)
      expect(b.rate_limited?(:a)).to be_falsy
      clock.time = 102.0
      expect(b.rate_limited?(:a).round(2)).to eq(3)
    end

    it 'should not update last_time or count on blocked limit attempts' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(1, 10, nil, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy  # count = 1
      # Now blocked by limit
      5.times { expect(b.rate_limited?(:a)).to be_truthy }
      # After window expires, should be able to request again
      clock.advance(10)
      expect(b.rate_limited?(:a)).to be_falsy
    end

    it 'should not consume count on blocked delay attempts' do
      clock = FakeClock.new(100.0)
      b = BUCKET.new(3, 60, 5, clock: clock)
      expect(b.rate_limited?(:a)).to be_falsy  # count = 1
      # Now blocked by delay, should NOT consume count
      3.times { expect(b.rate_limited?(:a)).to be_truthy }
      clock.advance(5)
      expect(b.rate_limited?(:a)).to be_falsy  # count = 2
      clock.advance(5)
      expect(b.rate_limited?(:a)).to be_falsy  # count = 3
      # Now blocked by limit (3 used)
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should be thread-safe under concurrent access' do
      clock = OnyxCord::Commands::MonotonicClock.new
      b = BUCKET.new(5, 60, nil, clock: clock)
      results = Array.new(50) { nil }
      threads = 50.times.map do |i|
        Thread.new { results[i] = b.rate_limited?(:a) }
      end
      threads.each(&:join)

      passed = results.count { |r| r == false }
      blocked = results.count { |r| r != false }
      expect(passed).to eq(5)
      expect(blocked).to eq(45)
    end
  end
end
