# frozen_string_literal: true

require 'onyxcord'
require 'spec_helper'

RSpec.describe 'Command middleware' do
  def command_event_double
    double('event').tap do |event|
      allow(event).to receive(:command=)
      allow(event).to receive(:drain_into) { |e| e }
      allow(event).to receive(:server)
      allow(event).to receive(:channel)
      allow(event).to receive(:bot) do
        double('bot').tap do |bot|
          allow(bot).to receive(:token) { 'fake token' }
          allow(bot).to receive(:rate_limited?) { false }
          allow(bot).to receive(:attributes) { {} }
        end
      end
      allow(event).to receive(:author) do
        double('member').tap do |member|
          allow(member).to receive(:id) { 321 }
          allow(member).to receive(:roles) { [] }
          allow(member).to receive(:permission?) { true }
          allow(member).to receive(:webhook?) { false }
        end
      end
    end
  end

  describe 'Command#before' do
    it 'runs before hook before the command block' do
      order = []
      cmd = OnyxCord::Commands::Command.new(:test) { order << :command }
      cmd.before { |_event| order << :before }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(order).to eq(%i[before command])
    end

    it 'cancels execution when before hook returns false' do
      called = false
      cmd = OnyxCord::Commands::Command.new(:test) { called = true }
      cmd.before { |_event| false }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(called).to be false
    end

    it 'supports multiple before hooks in order' do
      order = []
      cmd = OnyxCord::Commands::Command.new(:test) { order << :command }
      cmd.before { order << :first }
      cmd.before { order << :second }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(order).to eq(%i[first second command])
    end

    it 'stops at the first hook that returns false' do
      order = []
      cmd = OnyxCord::Commands::Command.new(:test) { order << :command }
      cmd.before { order << :first }
      cmd.before do
        order << :second
        false
      end
      cmd.before { order << :third }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(order).to eq(%i[first second])
    end

    it 'passes event and arguments to the hook' do
      received_args = nil
      cmd = OnyxCord::Commands::Command.new(:test) { 'ok' }
      cmd.before { |_event, *args| received_args = args }

      event = command_event_double
      cmd.call(event, %w[hello world], false, false)
      expect(received_args).to eq(%w[hello world])
    end

    it 'returns self for chaining' do
      cmd = OnyxCord::Commands::Command.new(:test) { 'ok' }
      result = cmd.before { true }
      expect(result).to equal(cmd)
    end
  end

  describe 'Command#after' do
    it 'runs after hook after the command block' do
      order = []
      cmd = OnyxCord::Commands::Command.new(:test) do
        order << :command
        'result'
      end
      cmd.after { |_event, _args, _result| order << :after }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(order).to eq(%i[command after])
    end

    it 'receives the command result as last argument' do
      received_result = nil
      cmd = OnyxCord::Commands::Command.new(:test) { 'hello' }
      cmd.after { |_event, result| received_result = result }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(received_result).to eq('hello')
    end

    it 'receives arguments before result when arguments are present' do
      received_args = nil
      cmd = OnyxCord::Commands::Command.new(:test) { 'hello' }
      cmd.after do |_event, *args|
        received_args = args
      end

      event = command_event_double
      cmd.call(event, %w[a b], false, false)
      expect(received_args).to eq(%w[a b hello])
    end

    it 'supports multiple after hooks' do
      order = []
      cmd = OnyxCord::Commands::Command.new(:test) { 'ok' }
      cmd.after { order << :first }
      cmd.after { order << :second }

      event = command_event_double
      cmd.call(event, [], false, false)
      expect(order).to eq(%i[first second])
    end

    it 'returns self for chaining' do
      cmd = OnyxCord::Commands::Command.new(:test) { 'ok' }
      result = cmd.after { nil }
      expect(result).to equal(cmd)
    end
  end

  describe 'CommandContainer#middleware' do
    it 'registers a before hook on a command' do
      order = []
      container = Class.new do
        include OnyxCord::Commands::CommandContainer
      end.new

      container.command(:test) { order << :command }
      container.middleware(:test, :before) { order << :before }

      event = command_event_double
      container.commands[:test].call(event, [], false, false)
      expect(order).to eq(%i[before command])
    end

    it 'registers an after hook on a command' do
      order = []
      container = Class.new do
        include OnyxCord::Commands::CommandContainer
      end.new

      container.command(:test) { order << :command }
      container.middleware(:test, :after) { order << :after }

      event = command_event_double
      container.commands[:test].call(event, [], false, false)
      expect(order).to eq(%i[command after])
    end

    it 'resolves through CommandAlias' do
      order = []
      container = Class.new do
        include OnyxCord::Commands::CommandContainer
      end.new

      container.command(:real, aliases: [:alias]) { order << :command }
      container.middleware(:alias, :before) { order << :before }

      event = command_event_double
      container.commands[:real].call(event, [], false, false)
      expect(order).to eq(%i[before command])
    end

    it 'returns self for chaining' do
      container = Class.new do
        include OnyxCord::Commands::CommandContainer
      end.new

      container.command(:test) { 'ok' }
      result = container.middleware(:test, :before) { true }
      expect(result).to equal(container)
    end

    it 'returns self when command does not exist' do
      container = Class.new do
        include OnyxCord::Commands::CommandContainer
      end.new

      result = container.middleware(:nonexistent, :before) { true }
      expect(result).to equal(container)
    end
  end
end
