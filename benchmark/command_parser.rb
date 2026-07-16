# frozen_string_literal: true

require_relative '../lib/onyxcord'

puts '--- Benchmark: Command Chain & Parser Baseline ---'

bot = OnyxCord::Commands::Bot.new(token: 'benchmark_token', help_available: false, advanced_functionality: true)
bot.command(:echo) { |_event, arg| arg }
bot.command(:add) { |_event, *args| args.map(&:to_i).sum.to_s }

chain_input = 'echo "hello world" > echo ~ : repeat 5'
chain = OnyxCord::Commands::CommandChain.new(chain_input, bot)

MockAuthor = Struct.new(:id)
MockChannel = Struct.new(:id, :name) do
  def resolve_id; id; end
end
MockServer = Struct.new(:id)

MockEvent = Struct.new(:bot, :author, :command, :channel, :server) do
  def respond(*args); end
  def drain_into(x); x; end
end

event = MockEvent.new(bot, MockAuthor.new(123), nil, MockChannel.new(456, 'general'), MockServer.new(789))

# Measure allocations and duration of execute_bare / execute
before_alloc = GC.stat(:total_allocated_objects)
start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
1_000.times do
  OnyxCord::Commands::CommandChain.new(chain_input, bot).execute(event)
end
duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
alloc_diff = GC.stat(:total_allocated_objects) - before_alloc

puts "1,000 chain executions took #{'%.4f' % duration}s (#{'%.2f' % (1000 / duration)} chains/sec)"
puts "1,000 chain executions allocated #{alloc_diff} objects (#{'%.2f' % (alloc_diff / 1000.0)} objects/chain)"
