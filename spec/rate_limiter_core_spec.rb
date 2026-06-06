# frozen_string_literal: true

require 'onyxcord/rate_limiter/gateway'
require 'onyxcord/rate_limiter/rest'

describe OnyxCord::RateLimiter::Gateway do
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

describe OnyxCord::RateLimiter::Rest do
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
end
