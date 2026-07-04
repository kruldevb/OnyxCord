# frozen_string_literal: true

require 'onyxcord/rest/client'

describe OnyxCord::REST do
  it 'raises typed HTTPError for non-json HTTP failures' do
    response = instance_double('Response', code: 418, body: '<html>bad</html>', headers: { server: 'cloudflare' })
    allow(OnyxCord::Internal::HTTP).to receive(:request).and_return(response)

    expect do
      described_class.request_async(:test_route, nil, :post, 'https://discord.test/webhooks/1/token', 'body')
    end.to raise_error(OnyxCord::Errors::HTTPError) { |error|
      expect(error.status).to eq(418)
      expect(error.code).to eq(0)
      expect(error.headers).to eq(server: 'cloudflare')
      expect(error.route).to include('/webhooks/1/[token]')
      expect(error.body).to eq('<html>bad</html>')
    }
  end

  it 'raises NoPermission with HTTP metadata for 403 responses' do
    response = instance_double('Response', code: 403, body: '{"message":"Missing Permissions"}', headers: { h: 'v' })
    allow(OnyxCord::Internal::HTTP).to receive(:request).and_return(response)

    expect do
      described_class.request_async(:test_route, 123, :get, 'https://discord.test/channels/123')
    end.to raise_error(OnyxCord::Errors::NoPermission) { |error|
      expect(error.status).to eq(403)
      expect(error.headers).to eq(h: 'v')
      expect(error.body).to eq('{"message":"Missing Permissions"}')
      expect(error.route).to include('GET https://discord.test/channels/123')
    }
  end
end
