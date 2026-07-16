# frozen_string_literal: true

require 'securerandom'
require 'onyxcord/webhooks'

describe OnyxCord::Webhooks do
  describe OnyxCord::Webhooks::Builder do
    it 'should be able to add embeds' do
      builder = OnyxCord::Webhooks::Builder.new

      embed = builder.add_embed do |e|
        e.title = 'a'
        e.image = OnyxCord::Webhooks::EmbedImage.new(url: 'https://example.com/image.png')
      end

      expect(builder.embeds.length).to eq 1
      expect(builder.embeds.first).to eq embed
    end

    it 'allows files and embeds to coexist' do
      builder = OnyxCord::Webhooks::Builder.new
      builder.file = StringIO.new('test')
      builder.add_embed { |e| e.title = 'test' }

      expect(builder.file).not_to be_nil
      expect(builder.embeds.length).to eq 1
    end

    it 'adds embed without a block' do
      builder = OnyxCord::Webhooks::Builder.new
      existing = OnyxCord::Webhooks::Embed.new(title: 'existing')
      result = builder.add_embed(existing)

      expect(result).to eq existing
      expect(builder.embeds).to include(existing)
    end

    it 'creates an empty embed when called without arguments' do
      builder = OnyxCord::Webhooks::Builder.new
      embed = builder.add_embed

      expect(embed).to be_a(OnyxCord::Webhooks::Embed)
      expect(builder.embeds.length).to eq 1
    end
  end

  describe OnyxCord::Webhooks::EditBuilder do
    it 'creates a builder with UNSET sentinels' do
      edit = OnyxCord::Webhooks::EditBuilder.new

      hash = edit.to_json_hash
      expect(hash).to be_empty
    end

    it 'includes only explicitly set fields' do
      edit = OnyxCord::Webhooks::EditBuilder.new
      edit.content = 'hello'

      hash = edit.to_json_hash
      expect(hash).to eq({ content: 'hello' })
      expect(hash).not_to have_key(:embeds)
      expect(hash).not_to have_key(:allowed_mentions)
    end

    it 'allows setting content to nil to clear it' do
      edit = OnyxCord::Webhooks::EditBuilder.new
      edit.content = nil

      hash = edit.to_json_hash
      expect(hash).to have_key(:content)
      expect(hash[:content]).to be_nil
    end

    it 'supports block-style building' do
      edit = OnyxCord::Webhooks::EditBuilder.new do |e|
        e.content = 'edited'
        e.embeds = []
      end

      hash = edit.to_json_hash
      expect(hash[:content]).to eq 'edited'
      expect(hash[:embeds]).to eq []
    end
  end

  describe OnyxCord::Webhooks::Embed do
    it 'should be able to have fields added' do
      embed = OnyxCord::Webhooks::Embed.new

      embed.add_field(name: 'a', value: 'b', inline: true)

      expect(embed.fields.length).to eq 1
    end

    describe '#to_hash' do
      it 'does not include video or provider' do
        embed = OnyxCord::Webhooks::Embed.new
        embed.instance_variable_set(:@video, double('video'))
        embed.instance_variable_set(:@provider, double('provider'))

        hash = embed.to_hash
        expect(hash).not_to have_key(:video)
        expect(hash).not_to have_key(:provider)
      end

      it 'does not include nil values' do
        embed = OnyxCord::Webhooks::Embed.new
        hash = embed.to_hash

        expect(hash).not_to have_key(:title)
        expect(hash).not_to have_key(:description)
        expect(hash).not_to have_key(:url)
        expect(hash).not_to have_key(:timestamp)
        expect(hash).not_to have_key(:color)
        expect(hash).not_to have_key(:footer)
        expect(hash).not_to have_key(:image)
        expect(hash).not_to have_key(:thumbnail)
        expect(hash).not_to have_key(:author)
      end

      it 'does not include empty fields array' do
        embed = OnyxCord::Webhooks::Embed.new
        hash = embed.to_hash

        expect(hash).not_to have_key(:fields)
      end
    end

    describe '#colour=' do
      it 'should accept colours in decimal format' do
        embed = OnyxCord::Webhooks::Embed.new
        colour = 1234

        embed.colour = colour
        expect(embed.colour).to eq colour
      end

      it 'should raise if the colour value is too high' do
        embed = OnyxCord::Webhooks::Embed.new
        colour = 100_000_000

        expect { embed.colour = colour }.to raise_error(ArgumentError)
      end

      it 'should accept colours in hex format' do
        embed = OnyxCord::Webhooks::Embed.new
        colour = '162a3f'

        embed.colour = colour
        expect(embed.colour).to eq 1_452_607
      end

      it 'should accept colours in hex format with a # in front' do
        embed = OnyxCord::Webhooks::Embed.new
        colour = '#162a3f'

        embed.colour = colour
        expect(embed.colour).to eq 1_452_607
      end

      it 'should accept colours as a RGB tuple' do
        embed = OnyxCord::Webhooks::Embed.new
        colour = [22, 42, 63]

        embed.colour = colour
        expect(embed.colour).to eq 1_452_607
      end

      it 'should raise if a RGB tuple is of the wrong size' do
        embed = OnyxCord::Webhooks::Embed.new

        expect { embed.colour = [0, 1] }.to raise_error(ArgumentError)
        expect { embed.colour = [0, 1, 2, 3] }.to raise_error(ArgumentError)
      end

      it 'should raise if a RGB tuple results in a too large value' do
        embed = OnyxCord::Webhooks::Embed.new

        expect { embed.colour = [2000, 1, 2] }.to raise_error(ArgumentError)
      end

      it 'accepts ColourRGB objects' do
        embed = OnyxCord::Webhooks::Embed.new
        crgb = OnyxCord::ColourRGB.new(0x162a3f)

        embed.colour = crgb
        expect(embed.colour).to eq 0x162a3f
      end
    end

    describe '#timestamp=' do
      it 'accepts Time objects' do
        embed = OnyxCord::Webhooks::Embed.new
        t = Time.now.utc
        embed.timestamp = t

        expect(embed.timestamp).to be_a(Time)
        expect(embed.timestamp.utc?).to be true
      end

      it 'accepts DateTime objects' do
        embed = OnyxCord::Webhooks::Embed.new
        require 'date'
        dt = DateTime.now
        embed.timestamp = dt

        expect(embed.timestamp).to be_a(Time)
      end

      it 'accepts ISO-8601 strings' do
        embed = OnyxCord::Webhooks::Embed.new
        embed.timestamp = '2024-01-15T12:00:00Z'

        expect(embed.timestamp).to be_a(Time)
      end

      it 'rejects invalid objects' do
        embed = OnyxCord::Webhooks::Embed.new

        expect { embed.timestamp = 12345 }.to raise_error(ArgumentError)
      end
    end
  end

  describe OnyxCord::Webhooks::Client do
    let(:id) { '123456789012345678' }
    let(:token) { 'abcdefghij1234567890' }
    let(:valid_url) { "https://discord.com/api/v10/webhooks/#{id}/#{token}" }
    let(:provided_url) { valid_url }

    subject { described_class.new(url: provided_url) }

    describe '#initialize' do
      it 'generates a url from id and token' do
        client = described_class.new(id: id, token: token)

        expect(client.webhook_id).to eq id
      end

      it 'takes a provided url' do
        client = described_class.new(url: provided_url)

        expect(client.webhook_id).to eq id
      end

      it 'rejects non-HTTPS URLs' do
        expect {
          described_class.new(url: 'http://discord.com/api/v10/webhooks/123/abc')
        }.to raise_error(ArgumentError, /HTTPS/)
      end

      it 'rejects non-discord hosts' do
        expect {
          described_class.new(url: 'https://evil.com/api/v10/webhooks/123/abc')
        }.to raise_error(ArgumentError, /discord.com/)
      end

      it 'rejects URLs with userinfo' do
        expect {
          described_class.new(url: 'https://user:pass@discord.com/api/v10/webhooks/123/abc')
        }.to raise_error(ArgumentError, /userinfo/)
      end

      it 'rejects URLs with control characters' do
        expect {
          described_class.new(url: "https://discord.com/api/v10/webhooks/123/abc\x00")
        }.to raise_error(ArgumentError, /control/)
      end

      it 'raises when neither url nor id+token provided' do
        expect { described_class.new }.to raise_error(ArgumentError)
      end
    end

    describe '#inspect' do
      it 'redacts the token' do
        client = described_class.new(url: valid_url)
        expect(client.inspect).not_to include(token)
        expect(client.inspect).to include('[token]')
      end
    end

    describe '#execute' do
      let(:json_hash) { instance_double(Hash) }
      let(:default_builder) { instance_double(OnyxCord::Webhooks::Builder, to_json_hash: json_hash) }

      before do
        allow(subject).to receive(:post_json).with(any_args)
        allow(subject).to receive(:post_multipart).with(any_args)
        allow(default_builder).to receive(:file).and_return(nil)
      end

      it 'takes a default builder' do
        expect { |b| subject.execute(default_builder, &b) }.to yield_with_args(default_builder, instance_of(OnyxCord::Webhooks::View))
      end

      context 'when a builder is not provided' do
        it 'creates a new builder if none is provided' do
          expect { |b| subject.execute(&b) }.to yield_with_args(
            instance_of(OnyxCord::Webhooks::Builder),
            instance_of(OnyxCord::Webhooks::View)
          )
        end
      end

      context 'when a file is provided' do
        it 'POSTs multipart data' do
          allow(default_builder).to receive(:file).and_return(true)

          subject.execute(default_builder)

          expect(subject).to have_received(:post_multipart).with(default_builder, any_args)
        end
      end

      context 'when a file is not provided' do
        it 'POSTs json data' do
          subject.execute(default_builder)

          expect(subject).to have_received(:post_json).with(default_builder, any_args)
        end
      end

      it 'rejects builders that do not satisfy the duck type' do
        expect {
          subject.execute(Object.new)
        }.to raise_error(TypeError, /to_json_hash/)
      end
    end

    describe '#modify' do
      before do
        allow(OnyxCord::REST.default_client).to receive(:request).and_return(
          instance_double(OnyxCord::Internal::HTTP::Response, code: 200, body: '{}')
        )
      end

      it 'does not accept channel_id' do
        subject.modify(name: 'test')

        expect(OnyxCord::REST.default_client).to have_received(:request)
      end
    end

    describe '#delete' do
      before do
        allow(OnyxCord::REST.default_client).to receive(:request).and_return(
          instance_double(OnyxCord::Internal::HTTP::Response, code: 204, body: '')
        )
      end

      it 'does not send X-Audit-Log-Reason' do
        subject.delete

        expect(OnyxCord::REST.default_client).to have_received(:request).with(
          :webhook, id, :delete, anything, body: nil, headers: {}
        )
      end
    end

    describe '#edit_message' do
      let(:message_id) { '123456789012345678' }
      let(:json_hash) { {} }
      let(:default_builder) { instance_double(OnyxCord::Webhooks::Builder, to_json_hash: json_hash, file: nil) }

      before do
        allow(OnyxCord::REST.default_client).to receive(:request).and_return(
          instance_double(OnyxCord::Internal::HTTP::Response, code: 200, body: '{}')
        )
      end

      it 'creates a new builder if one is not provided' do
        expect { |b| subject.edit_message(message_id, &b) }.to yield_with_args(instance_of(OnyxCord::Webhooks::EditBuilder))
      end

      it 'uses the provided builder' do
        expect { |b| subject.edit_message(message_id, builder: default_builder, &b) }.to yield_with_args(default_builder)
      end

      it 'sends a PATCH request to the message URL' do
        subject.edit_message(message_id)

        expect(OnyxCord::REST.default_client).to have_received(:request).with(
          :webhook, id, :patch, anything,
          body: '{}',
          headers: { 'content-type' => 'application/json' }
        )
      end
    end

    describe '#delete_message' do
      let(:message_id) { '123456789012345678' }

      before do
        allow(OnyxCord::REST.default_client).to receive(:request).and_return(
          instance_double(OnyxCord::Internal::HTTP::Response, code: 204, body: '')
        )
      end

      it 'sends a DELETE request to the message URL' do
        subject.delete_message(message_id)

        expect(OnyxCord::REST.default_client).to have_received(:request).with(
          :webhook, id, :delete, anything, body: nil, headers: {}
        )
      end

      it 'includes thread_id when provided' do
        subject.delete_message(message_id, thread_id: '999')

        expect(OnyxCord::REST.default_client).to have_received(:request).with(
          :webhook, id, :delete, include('thread_id=999'), body: nil, headers: {}
        )
      end
    end

    describe '#get_message' do
      let(:message_id) { '123456789012345678' }

      before do
        allow(OnyxCord::REST.default_client).to receive(:request).and_return(
          instance_double(OnyxCord::Internal::HTTP::Response, code: 200, body: '{}')
        )
      end

      it 'sends a GET request' do
        subject.get_message(message_id)

        expect(OnyxCord::REST.default_client).to have_received(:request).with(
          :webhook, id, :get, anything, body: nil, headers: {}
        )
      end
    end

    describe '#avatarise' do
      let(:data) { SecureRandom.bytes(24) }

      it 'makes no changes if the argument does not respond to read' do
        expect(subject.__send__(:avatarise, data)).to be data
      end

      it 'returns multipart data if the argument responds to read' do
        # Use a minimal PNG header for MIME detection
        png_data = "\x89PNG\r\n\x1a\n".b + SecureRandom.bytes(24)
        encoded = subject.__send__(:avatarise, StringIO.new(png_data))
        expect(encoded).to eq "data:image/png;base64,#{Base64.strict_encode64(png_data)}"
      end

      it 'rejects avatars that are too large' do
        large_io = StringIO.new('x' * 300_000)
        expect { subject.__send__(:avatarise, large_io) }.to raise_error(ArgumentError, /too large/)
      end
    end
  end

  describe OnyxCord::Webhooks::View do
    describe '#container' do
      it 'yields the container builder' do
        view = OnyxCord::Webhooks::View.new
        yielded = nil

        view.container { |c| yielded = c }

        expect(yielded).to be_a(OnyxCord::Webhooks::View::ContainerBuilder)
      end
    end
  end

  describe OnyxCord::Webhooks::View::RowBuilder do
    describe '#button' do
      it 'validates that link buttons have a url' do
        row = OnyxCord::Webhooks::View::RowBuilder.new
        expect {
          row.button(style: :link)
        }.to raise_error(ArgumentError, /url/)
      end

      it 'validates that non-link buttons have a custom_id' do
        row = OnyxCord::Webhooks::View::RowBuilder.new
        expect {
          row.button(style: :primary, label: 'test')
        }.to raise_error(ArgumentError, /custom_id/)
      end

      it 'validates that buttons have a label or emoji' do
        row = OnyxCord::Webhooks::View::RowBuilder.new
        expect {
          row.button(style: :primary, custom_id: 'test')
        }.to raise_error(ArgumentError, /label or emoji/)
      end

      it 'validates premium buttons have sku_id' do
        row = OnyxCord::Webhooks::View::RowBuilder.new
        expect {
          row.button(style: :premium)
        }.to raise_error(ArgumentError, /sku_id/)
      end

      it 'rejects more than 5 buttons' do
        row = OnyxCord::Webhooks::View::RowBuilder.new
        5.times { |i| row.button(style: :primary, custom_id: "b#{i}", label: 'x') }
        expect {
          row.button(style: :primary, custom_id: 'b5', label: 'x')
        }.to raise_error(ArgumentError, /at most 5/)
      end
    end

    describe 'select menus' do
      it 'rejects mixing buttons and selects' do
        row = OnyxCord::Webhooks::View::RowBuilder.new
        row.button(style: :primary, custom_id: 'b1', label: 'x')
        expect {
          row.string_select(custom_id: 's1')
        }.to raise_error(ArgumentError, /mix/)
      end
    end
  end

  describe OnyxCord::Webhooks::View::SelectMenuBuilder do
    it 'does not include options for user_select' do
      builder = OnyxCord::Webhooks::View::SelectMenuBuilder.new('test', [], nil, nil, nil, nil, select_type: :user_select, default_values: [{ id: '123', type: 'user' }])
      hash = builder.to_h

      expect(hash).not_to have_key(:options)
      expect(hash).to have_key(:default_values)
    end

    it 'includes options for string_select' do
      builder = OnyxCord::Webhooks::View::SelectMenuBuilder.new('test', [{ label: 'a', value: 'b' }], nil, nil, nil, nil, select_type: :string_select)
      hash = builder.to_h

      expect(hash).to have_key(:options)
    end

    it 'does not include default_values for string_select' do
      builder = OnyxCord::Webhooks::View::SelectMenuBuilder.new('test', [], nil, nil, nil, nil, select_type: :string_select)
      hash = builder.to_h

      expect(hash).not_to have_key(:default_values)
    end
  end

  describe OnyxCord::Webhooks::View::SeparatorBuilder do
    it 'validates spacing values' do
      expect { OnyxCord::Webhooks::View::SeparatorBuilder.new(divider: true, spacing: 3) }.to raise_error(ArgumentError, /spacing/)
    end

    it 'accepts valid spacing values' do
      expect { OnyxCord::Webhooks::View::SeparatorBuilder.new(divider: true, spacing: 1) }.not_to raise_error
      expect { OnyxCord::Webhooks::View::SeparatorBuilder.new(divider: true, spacing: :small) }.not_to raise_error
    end
  end

  describe OnyxCord::Webhooks::View::SectionBuilder do
    it 'prevents setting both thumbnail and button' do
      section = OnyxCord::Webhooks::View::SectionBuilder.new
      section.thumbnail(url: 'https://example.com/image.png')

      expect {
        section.button(style: :primary, custom_id: 'test', label: 'x')
      }.to raise_error(ArgumentError, /mutually exclusive/)
    end

    it 'prevents setting both button and thumbnail' do
      section = OnyxCord::Webhooks::View::SectionBuilder.new
      section.button(style: :primary, custom_id: 'test', label: 'x')

      expect {
        section.thumbnail(url: 'https://example.com/image.png')
      }.to raise_error(ArgumentError, /mutually exclusive/)
    end
  end

  # =========================================================================
  #  WEBHOOK-0202: Embed limits validation
  # =========================================================================
  describe 'Embed limits validation' do
    it 'rejects titles exceeding 256 characters' do
      embed = OnyxCord::Webhooks::Embed.new(title: 'x' * 257)
      expect { embed.validate! }.to raise_error(ArgumentError, /title too long/)
    end

    it 'rejects descriptions exceeding 4096 characters' do
      embed = OnyxCord::Webhooks::Embed.new(description: 'x' * 4097)
      expect { embed.validate! }.to raise_error(ArgumentError, /description too long/)
    end

    it 'rejects more than 25 fields' do
      embed = OnyxCord::Webhooks::Embed.new
      26.times { |i| embed.add_field(name: "f#{i}", value: "v#{i}") }
      expect { embed.validate! }.to raise_error(ArgumentError, /Too many fields/)
    end

    it 'rejects field names exceeding 256 characters' do
      embed = OnyxCord::Webhooks::Embed.new
      embed.add_field(name: 'x' * 257, value: 'v')
      expect { embed.validate! }.to raise_error(ArgumentError, /Field.*name too long/)
    end

    it 'rejects field values exceeding 1024 characters' do
      embed = OnyxCord::Webhooks::Embed.new
      embed.add_field(name: 'n', value: 'x' * 1025)
      expect { embed.validate! }.to raise_error(ArgumentError, /Field.*value too long/)
    end

    it 'rejects footer text exceeding 2048 characters' do
      footer = OnyxCord::Webhooks::EmbedFooter.new(text: 'x' * 2049)
      embed = OnyxCord::Webhooks::Embed.new(footer: footer)
      expect { embed.validate! }.to raise_error(ArgumentError, /Footer text too long/)
    end

    it 'rejects author names exceeding 256 characters' do
      author = OnyxCord::Webhooks::EmbedAuthor.new(name: 'x' * 257)
      embed = OnyxCord::Webhooks::Embed.new(author: author)
      expect { embed.validate! }.to raise_error(ArgumentError, /Author name too long/)
    end

    it 'rejects more than 10 embeds in a builder' do
      builder = OnyxCord::Webhooks::Builder.new(content: 'x')
      11.times { |i| builder.add_embed { |e| e.title = "e#{i}" } }
      expect { builder.to_json_hash }.to raise_error(ArgumentError, /Too many embeds/)
    end

    it 'accepts valid embeds within limits' do
      embed = OnyxCord::Webhooks::Embed.new(title: 'x' * 256, description: 'y' * 4096)
      25.times { |i| embed.add_field(name: "f#{i}", value: "v#{i}") }
      expect { embed.validate! }.not_to raise_error
    end
  end

  # =========================================================================
  #  WEBHOOK-0208: Allowed mentions validation
  # =========================================================================
  describe 'Allowed mentions validation in builder' do
    before { require 'onyxcord/utils/allowed_mentions' }

    it 'accepts an AllowedMentions object' do
      am = OnyxCord::AllowedMentions.none
      builder = OnyxCord::Webhooks::Builder.new(content: 'x', allowed_mentions: am)
      expect(builder.allowed_mentions).to eq(am)
    end

    it 'converts a Hash to AllowedMentions' do
      builder = OnyxCord::Webhooks::Builder.new(content: 'x', allowed_mentions: { parse: [] })
      expect(builder.allowed_mentions).to be_a(OnyxCord::AllowedMentions)
    end

    it 'rejects non-AllowedMentions values' do
      expect {
        OnyxCord::Webhooks::Builder.new(content: 'x', allowed_mentions: 'invalid')
      }.to raise_error(ArgumentError, /must be an AllowedMentions, Hash, or nil/)
    end
  end

  # =========================================================================
  #  WEBHOOK-0306: String select validation
  # =========================================================================
  describe 'String select validation' do
    it 'rejects more than 25 options' do
      view = OnyxCord::Webhooks::View.new
      expect {
        view.row do |r|
          r.string_select(custom_id: 'test') do |s|
            26.times { |i| s.option(label: "o#{i}", value: "v#{i}") }
          end
        end
      }.to raise_error(ArgumentError, /Too many options/)
    end

    it 'rejects labels exceeding 100 characters' do
      view = OnyxCord::Webhooks::View.new
      expect {
        view.row do |r|
          r.string_select(custom_id: 'test') do |s|
            s.option(label: 'x' * 101, value: 'v')
          end
        end
      }.to raise_error(ArgumentError, /label too long/)
    end

    it 'rejects values exceeding 100 characters' do
      view = OnyxCord::Webhooks::View.new
      expect {
        view.row do |r|
          r.string_select(custom_id: 'test') do |s|
            s.option(label: 'l', value: 'x' * 101)
          end
        end
      }.to raise_error(ArgumentError, /value too long/)
    end

    it 'rejects descriptions exceeding 100 characters' do
      view = OnyxCord::Webhooks::View.new
      expect {
        view.row do |r|
          r.string_select(custom_id: 'test') do |s|
            s.option(label: 'l', value: 'v', description: 'x' * 101)
          end
        end
      }.to raise_error(ArgumentError, /description too long/)
    end

    it 'rejects duplicate option values' do
      view = OnyxCord::Webhooks::View.new
      expect {
        view.row do |r|
          r.string_select(custom_id: 'test') do |s|
            s.option(label: 'a', value: 'same')
            s.option(label: 'b', value: 'same')
          end
        end
      }.to raise_error(ArgumentError, /Duplicate option values/)
    end
  end

  # =========================================================================
  #  WEBHOOK-0309: Custom ID uniqueness validation
  # =========================================================================
  describe 'Custom ID uniqueness validation' do
    it 'rejects duplicate custom_ids across rows' do
      view = OnyxCord::Webhooks::View.new
      view.row do |r|
        r.button(style: :primary, custom_id: 'dup', label: 'a')
      end
      view.row do |r|
        r.button(style: :primary, custom_id: 'dup', label: 'b')
      end
      expect { view.to_a }.to raise_error(ArgumentError, /Duplicate custom_id/)
    end

    it 'accepts unique custom_ids' do
      view = OnyxCord::Webhooks::View.new
      view.row do |r|
        r.button(style: :primary, custom_id: 'id1', label: 'a')
      end
      view.row do |r|
        r.button(style: :primary, custom_id: 'id2', label: 'b')
      end
      expect { view.to_a }.not_to raise_error
    end
  end

  # =========================================================================
  #  WEBHOOK-0403: Immutable snapshots
  # =========================================================================
  describe 'Builder#snapshot' do
    it 'returns a frozen hash' do
      builder = OnyxCord::Webhooks::Builder.new(content: 'hello')
      snap = builder.snapshot
      expect(snap).to be_frozen
    end

    it 'returns a deep-frozen hash' do
      builder = OnyxCord::Webhooks::Builder.new(content: 'hello')
      builder.add_embed do |e|
        e.title = 'test'
      end
      snap = builder.snapshot
      expect(snap[:embeds]).to be_frozen
      expect(snap[:embeds].first).to be_frozen
    end

    it 'is independent of subsequent builder changes' do
      builder = OnyxCord::Webhooks::Builder.new(content: 'hello')
      snap = builder.snapshot
      builder.content = 'changed'
      expect(snap[:content]).to eq('hello')
    end
  end

  describe 'EditBuilder#snapshot' do
    it 'returns a frozen hash' do
      builder = OnyxCord::Webhooks::EditBuilder.new
      builder.content = 'test'
      snap = builder.snapshot
      expect(snap).to be_frozen
      expect(snap[:content]).to eq('test')
    end
  end

  # =========================================================================
  #  WEBHOOK-0401: Multipart streaming
  # =========================================================================
  describe OnyxCord::Internal::HTTP::MultipartStream do
    it 'reads multipart content in chunks' do
      file = StringIO.new('file data here')
      parts = [
        { name: 'files[0]', value: file, filename: 'test.txt', content_type: 'text/plain' },
        { name: 'payload_json', value: '{"content":"hi"}' }
      ]
      stream = described_class.new(parts, 'boundary')

      content = stream.read(1024)
      expect(content).to include('files[0]')
      expect(content).to include('test.txt')
      expect(content).to include('payload_json')
      expect(content).to include('{"content":"hi"}')
    end

    it 'supports rewind' do
      file = StringIO.new('data')
      parts = [{ name: 'f', value: file, filename: 'a.bin', content_type: 'application/octet-stream' }]
      stream = described_class.new(parts, 'b')

      stream.read(1024)
      stream.rewind
      first_read = stream.read(1024)
      expect(first_read).to include('f')
    end
  end
end
