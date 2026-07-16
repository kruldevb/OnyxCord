# frozen_string_literal: true

require_relative '../lib/onyxcord'

puts '--- Benchmark: Help Command Baseline ---'

bot = OnyxCord::Commands::Bot.new(token: 'benchmark_token', help_command: :help)

50.times do |i|
  bot.command("cmd_#{i}".to_sym, description: "This is command number #{i} with some sample usage and description text.") { 'ok' }
  bot.command("alias_#{i}".to_sym, aliases: ["a_#{i}".to_sym]) { 'ok' }
end

MockAuthor = Struct.new(:id) do
  def webhook?; false; end
  def is_a?(kls); false; end
  def permission?(_action, _channel); true; end
  def role?(_r); true; end
  def pm(msg); end
end
MockChannel = Struct.new(:id) do
  def pm?; false; end
  def pm(msg); end
end
MockEvent = Struct.new(:bot, :user, :channel, :command) do
  def respond(*args); end
  def drain_into(x); x; end
end

event = MockEvent.new(bot, MockAuthor.new(123), MockChannel.new(456), nil)

start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
before_alloc = GC.stat(:total_allocated_objects)

1_000.times do
  bot.execute_command(:help, event, [], false, false)
end

duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
alloc_diff = GC.stat(:total_allocated_objects) - before_alloc

puts "1,000 help calls (100 commands) took #{'%.4f' % duration}s (#{'%.2f' % (1_000 / duration)} calls/sec)"
puts "1,000 help calls allocated #{alloc_diff} objects (#{'%.2f' % (alloc_diff / 1_000.0)} objects/call)"
