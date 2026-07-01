# frozen_string_literal: true

require 'onyxcord/message_payload'
require 'onyxcord/allowed_mentions'
require 'stringio'

describe OnyxCord::MessagePayload do
  it 'builds upload metadata from wrapped files' do
    file = instance_double('File', path: '/tmp/lista.txt')

    expect(described_class.attachment_payload([file])).to eq([{ id: 0, filename: 'lista.txt' }])
  end

  it 'keeps disnake-style multipart order with wrapped uploads' do
    file = instance_double('File', path: '/tmp/lista.txt')
    body = described_class.multipart_body({ content: 'ok' }, [file])

    expect(body.map { |part| part[:name] }).to eq(['files[0]', 'payload_json'])
    expect(body.first[:filename]).to eq('lista.txt')
  end

  it 'rejects more than ten attachments' do
    expect do
      described_class.validate!(attachments: Array.new(11) { StringIO.new('x') })
    end.to raise_error(ArgumentError, /attachments cannot exceed 10/)
  end

  it 'rejects content with components v2' do
    components = [{ type: 17, components: [] }]

    expect do
      described_class.validate!(content: 'nope', components: components)
    end.to raise_error(ArgumentError, /Components V2/)
  end

  it 'clears embeds by default when editing content' do
    expect(described_class.edit_body('novo texto', nil)).to eq(content: 'novo texto', embeds: [])
  end

  it 'clears content by default when editing embeds' do
    embeds = [{ title: 'Novo embed' }]

    expect(described_class.edit_body(nil, embeds)).to eq(content: nil, embeds: embeds)
  end

  it 'keeps requested edit fields with :keep' do
    expect(described_class.edit_body('novo texto', :keep)).to eq(content: 'novo texto')
    expect(described_class.edit_body(:keep, [{ title: 'Novo embed' }])).to eq(embeds: [{ title: 'Novo embed' }])
  end
end

describe OnyxCord::AllowedMentions do
  it 'has disnake-style none and all helpers' do
    expect(described_class.none.to_hash).to eq(parse: [], users: [], roles: [], replied_user: false)
    expect(described_class.all.to_hash).to eq(parse: %w[users roles everyone], replied_user: true)
  end
end
