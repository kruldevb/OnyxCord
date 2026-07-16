# frozen_string_literal: true

require_relative '../lib/onyxcord'
require 'objspace'

puts '--- Benchmark: Rate Limiter & Bucket Baseline ---'

bucket = OnyxCord::Commands::Bucket.new(5, 60, 1)

MockUser = Struct.new(:id) do
  def resolve_id; id; end
end

user = MockUser.new(123)

start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
before_alloc = GC.stat(:total_allocated_objects)

100_000.times do
  bucket.rate_limited?(user)
end

duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
alloc_diff = GC.stat(:total_allocated_objects) - before_alloc

puts "100,000 rate_limited? checks took #{'%.4f' % duration}s (#{'%.2f' % (100_000 / duration)} calls/sec)"
puts "100,000 rate_limited? checks allocated #{alloc_diff} objects (#{'%.2f' % (alloc_diff / 100_000.0)} objects/call)"

# Measure memory size of bucket entries when populating 100,000 different users
bucket_heavy = OnyxCord::Commands::Bucket.new(5, 60, 1)
100_000.times do |i|
  bucket_heavy.rate_limited?(i)
end

memsize = ObjectSpace.memsize_of(bucket_heavy) + bucket_heavy.instance_variable_get(:@bucket).sum { |k, v| ObjectSpace.memsize_of(k) + ObjectSpace.memsize_of(v) }
puts "100,000 Bucket entries consumed approximately #{memsize / 1024.0 / 1024.0} MB of memory"
