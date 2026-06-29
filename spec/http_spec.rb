# frozen_string_literal: true

require 'onyxcord/http'

describe OnyxCord::HTTP do
  after do
    described_class.reset!
  end

  it 'keeps a persistent session per thread' do
    described_class.reset!
    main_session = described_class.session
    worker_session = nil

    Thread.new do
      described_class.reset!
      worker_session = described_class.session
    end.join

    expect(described_class.session).to be(main_session)
    expect(worker_session).not_to be(main_session)
  end
end
