# frozen_string_literal: true

require_relative '../lib/onyxcord'

puts '--- Benchmark: Commands Dispatch & Trigger Baseline ---'

bot = OnyxCord::Commands::Bot.new(token: 'benchmark_token', help_available: false)
bot.command(:ping) { 'pong' }

MockAuthor = Struct.new(:id)
MockMessage = Struct.new(:content, :from_bot?, :webhook?, :author) do
  def start_with?(str)
    content.start_with?(str)
  end

  def [](range_or_index)
    content[range_or_index]
  end
end

msg_no_cmd = MockMessage.new('hello world from normal user', false, false, MockAuthor.new(123))
msg_cmd = MockMessage.new('!ping', false, false, MockAuthor.new(123))

# Measure object allocations for non-command message trigger check
before_alloc = GC.stat(:total_allocated_objects)
100_000.times do
  bot.send(:trigger?, msg_no_cmd)
end
alloc_diff = GC.stat(:total_allocated_objects) - before_alloc

puts "100,000 trigger? checks (non-command message) allocated #{alloc_diff} objects (#{'%.2f' % (alloc_diff / 100_000.0)} objects/call)"

# Measure object allocations for command message trigger check
before_alloc2 = GC.stat(:total_allocated_objects)
100_000.times do
  bot.send(:trigger?, msg_cmd)
end
alloc_diff2 = GC.stat(:total_allocated_objects) - before_alloc2

puts "100,000 trigger? checks (command message) allocated #{alloc_diff2} objects (#{'%.2f' % (alloc_diff2 / 100_000.0)} objects/call)"
