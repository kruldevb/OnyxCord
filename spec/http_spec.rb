# frozen_string_literal: true

require 'onyxcord/http'
require 'onyxcord/api'
require 'onyxcord/api/webhook'
require 'onyxcord/upload'

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

  it 'forces REST requests over HTTP/1.1' do
    base = class_double(HTTPX)
    persistent = instance_double('HTTPX::Session')
    redirects = instance_double('HTTPX::Session')
    session = instance_double('HTTPX::Session')

    allow(HTTPX).to receive(:plugin).with(:persistent).and_return(persistent)
    allow(persistent).to receive(:plugin).with(:follow_redirects).and_return(redirects)
    allow(redirects).to receive(:with).with(
      fallback_protocol: 'http/1.1',
      ssl: { alpn_protocols: ['http/1.1'] }
    ).and_return(session)

    described_class.session

    expect(redirects).to have_received(:with).with(
      fallback_protocol: 'http/1.1',
      ssl: { alpn_protocols: ['http/1.1'] }
    )
  end

  it 'posts multipart bodies with Net::HTTP' do
    response = instance_double('Net::HTTPResponse', body: '{}', code: '200', to_hash: {})
    http = instance_double('Net::HTTP')
    file = instance_double('File', read: 'data', rewind: nil, path: '/tmp/file.txt')
    body = { 'files[0]' => file, payload_json: '{}' }
    request = nil

    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      request = req
      response
    end

    described_class.request(:post, 'https://discord.test/upload', body)

    expect(Net::HTTP).to have_received(:start).with('discord.test', 443, use_ssl: true)
    expect(request.body).to include('name="files[0]"; filename="file.txt"')
    expect(request.body).to include("Content-Type: text/plain\r\n\r\n")
    expect(request.body).to include('name="payload_json"')
    expect(request.body).to include("name=\"payload_json\"\r\n\r\n{}")
  end

  it 'uses disnake-style multipart ordering' do
    file = instance_double('File', path: '/tmp/file.txt')
    body = OnyxCord::API::Webhook.multipart_body({ content: 'ok' }, [file])

    expect(body.map { |part| part[:name] }).to eq(['files[0]', 'payload_json'])
  end

  it 'supports Upload wrappers in legacy multipart hashes' do
    file = instance_double('File', read: 'data', rewind: nil)
    upload = OnyxCord::Upload.new(file, filename: 'lista.txt', content_type: 'text/plain')
    body = described_class.multipart_body({ file: upload, payload_json: '{}' }, 'boundary')

    expect(body).to include('filename="lista.txt"')
    expect(body).to include("Content-Type: text/plain\r\n\r\n")
  end

  it 'rejects legacy file mixed with attachments' do
    file = instance_double('File', path: '/tmp/file.txt')

    expect do
      OnyxCord::API::Webhook.token_execute_webhook('token', '123', false, 'ok', nil, nil, nil, file, nil, nil, nil, nil, [file])
    end.to raise_error(ArgumentError, /cannot mix file and attachments/)
  end
end
