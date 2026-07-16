# frozen_string_literal: true

require_relative '../lib/onyxcord'

puts '--- Benchmark: Permissions Check Baseline ---'

bot = OnyxCord::Commands::Bot.new(token: 'benchmark_token', help_available: false)

MockRole = Struct.new(:id)
MockMember = Struct.new(:id, :roles) do
  def permission?(_action, _channel); true; end
  def webhook?; false; end
  def role?(r)
    roles.any? { |user_r| user_r.id == (r.respond_to?(:resolve_id) ? r.resolve_id : r) }
  end
end
MockServer = Struct.new(:id)

bot.set_user_permission(123, 5)
bot.set_role_permission(456, 10)

member = MockMember.new(123, [MockRole.new(456), MockRole.new(789)])
server = MockServer.new(100)

start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
before_alloc = GC.stat(:total_allocated_objects)

100_000.times do
  bot.permission?(member, 5, server)
end

duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
alloc_diff = GC.stat(:total_allocated_objects) - before_alloc

puts "100,000 permission? checks took #{'%.4f' % duration}s (#{'%.2f' % (100_000 / duration)} calls/sec)"
puts "100,000 permission? checks allocated #{alloc_diff} objects (#{'%.2f' % (alloc_diff / 100_000.0)} objects/call)"
