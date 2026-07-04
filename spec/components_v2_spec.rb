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

    it 'keeps top-level components added during a container block after the container' do
      view = described_class.new do |v|
        v.container(color: '#2b2d31') do |container|
          container.text_display(content: 'Painel')

          v.row do |row|
            row.button(style: :secondary, label: 'Voltar', custom_id: 'voltar1')
          end

          v.container(color: '#313338') do |next_container|
            next_container.text_display(content: 'Segundo container')
          end
        end
      end

      expect(view.to_a).to eq(
        [
          {
            type: 17,
            accent_color: 0x2b2d31,
            spoiler: false,
            components: [{ type: 10, content: 'Painel' }]
          },
          {
            type: 1,
            components: [{ type: 2, label: 'Voltar', style: 2, custom_id: 'voltar1' }]
          },
          {
            type: 17,
            accent_color: 0x313338,
            spoiler: false,
            components: [{ type: 10, content: 'Segundo container' }]
          }
        ]
      )
    end

    it 'keeps top-level components in the order they are written' do
      view = described_class.new do |v|
        v.row do |row|
          row.button(style: :secondary, label: 'Voltar', custom_id: 'voltar1')
        end

        v.container(color: '#2b2d31') do |container|
          container.text_display(content: 'Painel')
        end
      end

      expect(view.to_a).to eq(
        [
          {
            type: 1,
            components: [{ type: 2, label: 'Voltar', style: 2, custom_id: 'voltar1' }]
          },
          {
            type: 17,
            accent_color: 0x2b2d31,
            spoiler: false,
            components: [{ type: 10, content: 'Painel' }]
          }
        ]
      )
    end

    it 'builds media gallery items from direct urls and hashes' do
      view = described_class.new do |v|
        v.media_gallery(
          'https://cdn.example.test/banner.png',
          { url: 'attachment://cover.png', description: 'Capa', spoiler: true }
        )

        v.container do |container|
          container.media_gallery('https://cdn.example.test/inside.png')
        end
      end

      expect(view.to_a).to eq(
        [
          {
            type: 12,
            items: [
              { media: { url: 'https://cdn.example.test/banner.png' }, spoiler: false },
              { media: { url: 'attachment://cover.png' }, description: 'Capa', spoiler: true }
            ]
          },
          {
            type: 17,
            spoiler: false,
            components: [
              { type: 12, items: [{ media: { url: 'https://cdn.example.test/inside.png' }, spoiler: false }] }
            ]
          }
        ]
      )
    end

    it 'builds file display components from direct attachment urls' do
      view = described_class.new do |v|
        v.file_display('attachment://receipt.txt')

        v.container do |container|
          container.file_display('attachment://inside.txt', spoiler: true)
        end
      end

      expect(view.to_a).to eq(
        [
          { type: 13, spoiler: false, file: { url: 'attachment://receipt.txt' } },
          {
            type: 17,
            spoiler: false,
            components: [
              { type: 13, spoiler: true, file: { url: 'attachment://inside.txt' } }
            ]
          }
        ]
      )
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

  describe OnyxCord::Webhooks::Modal do
    it 'builds modal labels with selects, text display, file upload, radio groups, checkbox groups, and checkboxes' do
      modal = described_class.new do |m|
        m.label(id: 1, label: 'Favorite bug', description: 'Choose one') do |label|
          label.string_select(custom_id: 'bug_string_select', placeholder: 'Choose...', required: true) do |menu|
            menu.option(label: 'Ant', value: 'ant', description: 'Tiny and strong')
          end
        end

        m.text_display(content: 'Extra context', id: 2)

        m.label(label: 'Upload evidence') do |label|
          label.file_upload(custom_id: 'evidence', min_values: 1, max_values: 3, required: false)
        end

        m.label(label: 'Pick one') do |label|
          label.radio_group(custom_id: 'priority', required: true) do |group|
            group.radio_button(label: 'High', value: 'high', description: 'Needs attention')
            group.radio_button(label: 'Low', value: 'low', default: true)
          end
        end

        m.label(label: 'Pick many') do |label|
          label.checkbox_group(custom_id: 'days', min_values: 0, max_values: 2, required: false) do |group|
            group.checkbox(label: 'Monday', value: 'mon')
            group.checkbox(label: 'Friday', value: 'fri', default: true)
          end
        end

        m.label(label: 'Confirm') do |label|
          label.checkbox(custom_id: 'confirm', default: true)
        end
      end

      expect(modal.to_a).to eq(
        [
          {
            type: 18,
            id: 1,
            label: 'Favorite bug',
            description: 'Choose one',
            component: {
              type: 3,
              options: [{ label: 'Ant', value: 'ant', description: 'Tiny and strong', emoji: nil, default: nil }],
              placeholder: 'Choose...',
              custom_id: 'bug_string_select',
              required: true
            }
          },
          { type: 10, id: 2, content: 'Extra context' },
          {
            type: 18,
            label: 'Upload evidence',
            component: { type: 19, custom_id: 'evidence', min_values: 1, max_values: 3, required: false }
          },
          {
            type: 18,
            label: 'Pick one',
            component: {
              type: 21,
              custom_id: 'priority',
              options: [
                { value: 'high', label: 'High', description: 'Needs attention' },
                { value: 'low', label: 'Low', default: true }
              ],
              required: true
            }
          },
          {
            type: 18,
            label: 'Pick many',
            component: {
              type: 22,
              custom_id: 'days',
              options: [
                { value: 'mon', label: 'Monday' },
                { value: 'fri', label: 'Friday', default: true }
              ],
              required: false,
              min_values: 0,
              max_values: 2
            }
          },
          {
            type: 18,
            label: 'Confirm',
            component: { type: 23, custom_id: 'confirm', default: true }
          }
        ]
      )
    end
  end

  describe OnyxCord::Webhooks::Client do
    it 'sends Components V2 flags and with_components for direct webhook execution' do
      client = described_class.new(url: 'https://discord.com/api/v9/webhooks/1/token')
      allow(OnyxCord::Internal::HTTP).to receive(:post)

      client.execute(nil, false) do |_builder, view|
        view.text_display(content: 'Webhook UI')
      end

      expect(OnyxCord::Internal::HTTP).to have_received(:post) do |url, body, headers|
        expect(url).to eq('https://discord.com/api/v9/webhooks/1/token?wait=false&with_components=true')
        expect(JSON.parse(body)).to include(
          'flags' => flag,
          'components' => [{ 'type' => 10, 'content' => 'Webhook UI' }]
        )
        expect(headers).to eq('content-type' => 'application/json')
      end
    end
  end

  describe OnyxCord::REST::Webhook do
    it 'adds with_components and IS_COMPONENTS_V2 for webhook token execution' do
      request = nil
      allow(OnyxCord::REST).to receive(:request) { |*args| request = args }

      described_class.token_execute_webhook(
        'token', 1, false, nil, nil, nil, nil, nil, nil, nil, nil,
        [{ type: 10, content: 'API UI' }]
      )

      expect(request[3]).to eq("#{OnyxCord::REST.api_base}/webhooks/1/token?wait=false&with_components=true")
      expect(JSON.parse(request[4])).to include(
        'flags' => flag,
        'components' => [{ 'type' => 10, 'content' => 'API UI' }]
      )
    end
  end

  describe OnyxCord::REST::Channel do
    it 'sets IS_COMPONENTS_V2 when creating a channel message with V2 components' do
      request = nil
      view = OnyxCord::Webhooks::View.new { |v| v.text_display(content: 'Channel UI') }
      allow(OnyxCord::REST).to receive(:request) { |*args| request = args }

      described_class.create_message('token', 1, nil, false, nil, nil, nil, nil, nil, view)

      expect(JSON.parse(request[4])).to include(
        'flags' => flag,
        'components' => [{ 'type' => 10, 'content' => 'Channel UI' }]
      )
    end
  end

  describe OnyxCord::REST::Interaction do
    it 'sets IS_COMPONENTS_V2 when responding with V2 components' do
      request = nil
      view = OnyxCord::Webhooks::View.new { |v| v.text_display(content: 'Interaction UI') }
      allow(OnyxCord::REST).to receive(:request) { |*args| request = args }

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

    it 'parses modal label and new modal input component payloads' do
      label = described_class.from_data(
        {
          'type' => 18,
          'id' => 10,
          'label' => 'Pick many',
          'description' => 'Choose all that apply',
          'component' => {
            'type' => 22,
            'id' => 11,
            'custom_id' => 'days',
            'values' => %w[mon fri]
          }
        },
        double('bot')
      )

      expect(label).to be_a(OnyxCord::Components::Label)
      expect(label.id).to eq(10)
      expect(label.label).to eq('Pick many')
      expect(label.description).to eq('Choose all that apply')
      expect(label.component).to be_a(OnyxCord::Components::CheckboxGroup)
      expect(label.custom_id).to eq('days')
      expect(label.values).to eq(%w[mon fri])
      expect(label.value).to be_nil
      expect(label.component.custom_id).to eq('days')
      expect(label.component.values).to eq(%w[mon fri])

      text_label = described_class.from_data(
        {
          'type' => 18,
          'label' => 'Prompt',
          'component' => {
            'type' => 4,
            'custom_id' => 'aichat_prompt',
            'value' => 'Answer like OnyxAI.'
          }
        },
        double('bot')
      )
      expect(text_label.custom_id).to eq('aichat_prompt')
      expect(text_label.value).to eq('Answer like OnyxAI.')
      expect(text_label.values).to be_nil

      expect(
        described_class.from_data(
          { 'type' => 19, 'custom_id' => 'evidence', 'values' => %w[123 456] },
          double('bot')
        ).values
      ).to eq([123, 456])
      expect(
        described_class.from_data(
          { 'type' => 21, 'custom_id' => 'priority', 'value' => 'high' },
          double('bot')
        ).value
      ).to eq('high')
      expect(
        described_class.from_data(
          { 'type' => 23, 'custom_id' => 'confirm', 'value' => true },
          double('bot')
        ).value
      ).to be(true)
    end
  end
end
