# frozen_string_literal: true

require 'onyxcord/internal/rate_limiter/gateway'
require 'onyxcord/internal/rate_limiter/rest'
require 'onyxcord/internal/rate_limiter/async_rest'

describe OnyxCord::Internal::RateLimiter::Gateway do
  it 'waits when the send window is full' do
    now = Time.at(0)
    waits = []
    limiter = described_class.new(
      limit: 2,
      interval: 60,
      clock: -> { now },
      sleeper: lambda do |duration|
        waits << duration
        now += duration
      end
    )

    limiter.wait
    limiter.wait
    limiter.wait

    expect(waits).to eq([60])
  end
end

describe OnyxCord::Internal::RateLimiter::AsyncRest do
  it 'blocks route requests while global rate limit lock is held' do
    limiter = described_class.new
    limiter.instance_variable_get(:@global_lock).lock
    queue = Queue.new

    thread = Thread.new do
      limiter.before_request(:channels_cid, 123)
      queue << :done
    end

    sleep 0.01
    expect(queue.empty?).to be(true)

    limiter.instance_variable_get(:@global_lock).unlock
    expect(queue.pop).to eq(:done)
    thread.join
  end
end

describe OnyxCord::Internal::RateLimiter::Rest do
  it 'records Discord bucket ids and waits on depleted buckets' do
    limiter = described_class.new
    waits = []
    allow(limiter).to receive(:sync_wait) { |duration, _mutex| waits << duration }

    limiter.record_response(
      :create_message,
      123,
      x_ratelimit_bucket: 'abc',
      x_ratelimit_remaining: '0',
      x_ratelimit_reset_after: '0.25'
    )

    route_buckets = limiter.instance_variable_get(:@route_buckets)
    expect(route_buckets[[:create_message, 123]]).to eq([:bucket, 'abc', 123])
    expect(waits).to eq([0.25])
  end

  it 'waits for route-scoped 429 responses' do
    limiter = described_class.new
    waits = []
    response = instance_double(
      'response',
      headers: { retry_after: '1.5' },
      body: { retry_after: 1.5 }.to_json
    )
    allow(limiter).to receive(:sync_wait) { |duration, _mutex| waits << duration }

    limiter.handle_rate_limit(:create_message, 123, response)

    expect(waits).to eq([1.5])
  end

  it 'waits for global 429 responses' do
    limiter = described_class.new
    waits = []
    response = instance_double(
      'response',
      headers: { x_ratelimit_global: 'true', retry_after: '2.0' },
      body: ''.to_json
    )
    allow(limiter).to receive(:sync_wait) { |duration, mutex| waits << [duration, mutex] }

    limiter.handle_rate_limit(:anything, nil, response)

    expect(waits.first.first).to eq(2.0)
    expect(waits.first.last).to eq(limiter.instance_variable_get(:@global_mutex))
  end

  it 'reports and prunes stale bucket bookkeeping' do
    now = Time.at(100)
    limiter = described_class.new(clock: -> { now }, entry_ttl: 10, prune_interval: nil)

    limiter.record_response(
      :create_message,
      123,
      x_ratelimit_bucket: 'abc',
      x_ratelimit_remaining: '1'
    )

    expect(limiter.stats[:route_buckets]).to eq(1)
    expect(limiter.stats[:tracked_keys]).to eq(2)

    now = Time.at(200)

    expect(limiter.prune!).to eq(2)
    expect(limiter.stats).to include(route_buckets: 0, bucket_mutexes: 0, tracked_keys: 0)
  end
end
