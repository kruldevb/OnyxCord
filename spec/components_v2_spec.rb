# frozen_string_literal: true

require 'onyxcord'
require 'onyxcord/webhooks'

describe 'Components V2 support' do
  let(:flag) { OnyxCord::MessageComponents::IS_COMPONENTS_V2 }

  describe OnyxCord::Webhooks::View do
    it 'builds text display payloads and marks the view as Components V2' do
      view = described_class.new do |v|
        v.text_display(content: 'Hello from Components V2', id: 10)
      end

      expect(view.to_a).to eq([{ type: 10, id: 10, content: 'Hello from Components V2' }])
      expect(view).to be_components_v2
      expect(view.flags).to eq(flag)
    end

    it 'does not force Components V2 for legacy-only action rows' do
      view = described_class.new do |v|
        v.row do |row|
          row.button(style: :primary, label: 'Click', custom_id: 'click')
        end
      end

      expect(view).not_to be_components_v2
      expect(view.flags).to eq(0)
    end

    it 'builds nested container and section payloads' do
      view = described_class.new do |v|
        v.container(color: '#112233') do |container|
          container.text_display(content: 'Status')
          container.section do |section|
            section.text_display(content: 'Open ticket')
            section.button(style: :premium, sku_id: 123)
          end
        end
      end

      expect(view.to_a).to eq(
        [
          {
            type: 17,
            accent_color: 0x112233,
            spoiler: false,
            components: [
              { type: 10, content: 'Status' },
              {
                type: 9,
                components: [{ type: 10, content: 'Open ticket' }],
                accessory: { type: 2, style: 6, sku_id: 123 }
              }
            ]
          }
        ]
      )
      expect(view.flags(4)).to eq(flag | 4)
    end
  end

  describe OnyxCord::Webhooks::Builder do
    it 'can explicitly enable the Components V2 message flag' do
      builder = described_class.new

      expect(builder.components_v2!).to be(builder)
      expect(builder).to be_components_v2
      expect(builder.to_json_hash[:flags]).to eq(flag)
    end
  end

  describe OnyxCord::Webhooks::Client do
    it 'sends Components V2 flags and with_components for direct webhook execution' do
      client = described_class.new(url: 'https://discord.com/api/v9/webhooks/1/token')
      allow(RestClient).to receive(:post)

      client.execute(nil, false) do |_builder, view|
        view.text_display(content: 'Webhook UI')
      end

      expect(RestClient).to have_received(:post) do |url, body, headers|
        expect(url).to eq('https://discord.com/api/v9/webhooks/1/token?wait=false&with_components=true')
        expect(JSON.parse(body)).to include(
          'flags' => flag,
          'components' => [{ 'type' => 10, 'content' => 'Webhook UI' }]
        )
        expect(headers).to eq(content_type: :json)
      end
    end
  end

  describe OnyxCord::API::Webhook do
    it 'adds with_components and IS_COMPONENTS_V2 for webhook token execution' do
      request = nil
      allow(OnyxCord::API).to receive(:request) { |*args| request = args }

      described_class.token_execute_webhook(
        'token', 1, false, nil, nil, nil, nil, nil, nil, nil, nil,
        [{ type: 10, content: 'API UI' }]
      )

      expect(request[3]).to eq("#{OnyxCord::API.api_base}/webhooks/1/token?wait=false&with_components=true")
      expect(JSON.parse(request[4])).to include(
        'flags' => flag,
        'components' => [{ 'type' => 10, 'content' => 'API UI' }]
      )
    end
  end

  describe OnyxCord::API::Channel do
    it 'sets IS_COMPONENTS_V2 when creating a channel message with V2 components' do
      request = nil
      view = OnyxCord::Webhooks::View.new { |v| v.text_display(content: 'Channel UI') }
      allow(OnyxCord::API).to receive(:request) { |*args| request = args }

      described_class.create_message('token', 1, nil, false, nil, nil, nil, nil, nil, view)

      expect(JSON.parse(request[4])).to include(
        'flags' => flag,
        'components' => [{ 'type' => 10, 'content' => 'Channel UI' }]
      )
    end
  end

  describe OnyxCord::API::Interaction do
    it 'sets IS_COMPONENTS_V2 when responding with V2 components' do
      request = nil
      view = OnyxCord::Webhooks::View.new { |v| v.text_display(content: 'Interaction UI') }
      allow(OnyxCord::API).to receive(:request) { |*args| request = args }

      described_class.create_interaction_response('token', 1, 4, nil, nil, nil, nil, 64, view)

      data = JSON.parse(request[4])['data']
      expect(data).to include(
        'flags' => flag | 64,
        'components' => [{ 'type' => 10, 'content' => 'Interaction UI' }]
      )
    end
  end

  describe OnyxCord::Components do
    it 'parses received Components V2 payloads' do
      component = described_class.from_data(
        {
          'type' => 17,
          'accent_color' => 0x112233,
          'components' => [
            { 'type' => 10, 'id' => 2, 'content' => 'Parsed UI' }
          ]
        },
        double('bot')
      )

      expect(component).to be_a(OnyxCord::Components::Container)
      expect(component.components.first).to be_a(OnyxCord::Components::TextDisplay)
      expect(component.components.first.content).to eq('Parsed UI')
    end
  end
end
