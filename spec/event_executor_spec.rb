# frozen_string_literal: true

require 'onyxcord/internal/event_executor'

describe OnyxCord::Internal::EventExecutor do
  describe OnyxCord::Internal::EventExecutor::Inline do
    it 'runs jobs immediately' do
      ran = false

      described_class.new.post { ran = true }

      expect(ran).to be(true)
    end
  end

  describe OnyxCord::Internal::EventExecutor::Pool do
    it 'uses a fixed number of worker threads and drains queued jobs on shutdown' do
      executor = described_class.new(size: 2)
      mutex = Mutex.new
      count = 0

      5.times do
        executor.post do
          mutex.synchronize { count += 1 }
        end
      end

      expect(executor.threads.length).to eq(2)
      executor.shutdown
      expect(count).to eq(5)
    end

    it 'keeps processing after a job raises' do
      executor = described_class.new(size: 1)
      ran = false
      stub_const('OnyxCord::LOGGER', instance_double('logger', log_exception: nil))

      executor.post { raise 'boom' }
      executor.post { ran = true }
      executor.shutdown

      expect(ran).to be(true)
    end

    it 'uses a sized queue when configured' do
      executor = described_class.new(size: 1, queue_size: 2)

      expect(executor.queue).to be_a(SizedQueue)
      expect(executor.queue.max).to eq(2)
      executor.shutdown
    end
  end
end
