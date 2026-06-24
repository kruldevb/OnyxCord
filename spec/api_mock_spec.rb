# frozen_string_literal: true

require 'onyxcord'
require 'mock/api_mock'
using APIMock

describe APIMock do
  it 'stores the used method' do
    OnyxCord::API.raw_request(:get, [])

    expect(OnyxCord::API.last_method).to eq :get
  end

  it 'stores the used URL' do
    url = 'https://example.com/test'
    OnyxCord::API.raw_request(:get, [url])

    expect(OnyxCord::API.last_url).to eq url
  end

  it 'parses the stored body using JSON' do
    body = { test: 1 }
    OnyxCord::API.raw_request(:post, ['https://example.com/test', body.to_json])

    expect(OnyxCord::API.last_body['test']).to eq 1
  end

  it "doesn't parse the body if there is none present" do
    OnyxCord::API.raw_request(:post, ['https://example.com/test', nil])

    expect(OnyxCord::API.last_body).to be_nil
  end

  it 'parses headers if there is no body' do
    OnyxCord::API.raw_request(:post, ['https://example.com/test', nil, { a: 1, b: 2 }])

    expect(OnyxCord::API.last_headers[:a]).to eq 1
    expect(OnyxCord::API.last_headers[:b]).to eq 2
  end

  it 'parses body and headers if there is a body' do
    OnyxCord::API.raw_request(:post, ['https://example.com/test', { test: 1 }.to_json, { a: 1, b: 2 }])

    expect(OnyxCord::API.last_body['test']).to eq 1
    expect(OnyxCord::API.last_headers[:a]).to eq 1
    expect(OnyxCord::API.last_headers[:b]).to eq 2
  end
end

describe OnyxCord::API do
  after { described_class.reset_mutexes }

  it 'retries 202 search responses with the original route and major parameter' do
    first_response = instance_double(
      'response',
      code: 202,
      body: { code: 110_000, retry_after: 2 }.to_json,
      headers: {}
    )
    second_response = instance_double('response', code: 200, body: '{}', headers: {})

    allow(RestClient).to receive(:get).and_return(first_response, second_response)
    allow(described_class).to receive(:sleep)

    result = described_class.request(:search_messages, 123, :get, 'https://example.com/search', {})

    expect(result).to eq(second_response)
    expect(RestClient).to have_received(:get).twice
  end
end
