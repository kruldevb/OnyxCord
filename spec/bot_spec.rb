# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Bot do
  subject(:bot) do
    described_class.new(token: 'fake_token')
  end

  fixture :server_data, %i[emoji emoji_server]
  fixture_property :server_id, :server_data, ['id'], :to_i

  # TODO: Use some way of mocking the API instead of setting the server to not exist
  let!(:server) { OnyxCord::Server.new(server_data, bot) }

  fixture :dispatch_event, %i[emoji dispatch_event]
  fixture :dispatch_add, %i[emoji dispatch_add]

  fixture_property :emoji_1_name, :dispatch_add, ['emojis', 0, 'name']
  fixture_property :emoji_3_name, :dispatch_add, ['emojis', 2, 'name']

  fixture_property :emoji_1_id, :dispatch_add, ['emojis', 0, 'id'], :to_i
  fixture_property :emoji_2_id, :dispatch_add, ['emojis', 1, 'id'], :to_i
  fixture_property :emoji_3_id, :dispatch_add, ['emojis', 2, 'id'], :to_i

  fixture :dispatch_remove, %i[emoji dispatch_remove]
  fixture :dispatch_update, %i[emoji dispatch_update]

  fixture_property :edited_emoji_name, :dispatch_update, ['emojis', 1, 'name']

  before do
    bot.instance_variable_set(:@servers, server_id => server)
  end

  it 'should set up' do
    expect(bot.server(server_id)).to eq(server)
    expect(bot.server(server_id).emoji.size).to eq(2)
  end

  it 'raises when token string is empty or nil' do
    expect { described_class.new(token: '') }.to raise_error('Token string is empty or nil')
    expect { described_class.new(token: nil) }.to raise_error('Token string is empty or nil')
  end

  describe '#parse_mentions' do
    it 'parses user mentions' do
      user_a = double(:user_a)
      user_b = double(:user_b)
      allow(bot).to receive(:user).with('123').and_return(user_a)
      allow(bot).to receive(:user).with('456').and_return(user_b)
      mentions = bot.parse_mentions('<@!123><@!456>', server)
      expect(mentions).to eq([user_a, user_b])
    end

    it 'parses channel mentions' do
      channel_a = double(:channel_a)
      channel_b = double(:channel_b)
      allow(bot).to receive(:channel).with('123', server).and_return(channel_a)
      allow(bot).to receive(:channel).with('456', server).and_return(channel_b)
      mentions = bot.parse_mentions('<#123><#456>', server)
      expect(mentions).to eq([channel_a, channel_b])
    end

    it 'parses role mentions' do
      role_a = double(:role_a)
      role_b = double(:role_b)
      allow(server).to receive(:role).with('123').and_return(role_a)
      allow(server).to receive(:role).with('456').and_return(role_b)
      mentions = bot.parse_mentions('<@&123><@&456>')
      expect(mentions).to eq([role_a, role_b])
    end

    it 'parses emoji mentions' do
      emoji_a = double(:emoji_a)
      emoji_b = double(:emoji_b)
      allow(bot).to receive(:emoji).with('123').and_return(emoji_a)
      allow(bot).to receive(:emoji).with('456').and_return(emoji_b)
      mentions = bot.parse_mentions('<a:foo:123><a:bar:456>')
      expect(mentions).to eq([emoji_a, emoji_b])
    end

    it "doesn't parse invalid mentions" do
      mentions = bot.parse_mentions('<<@123<@?123><#123<:foo:123<b:foo:456><@abc><@!abc>', server)
      expect(mentions).to eq []
    end
  end

  describe '#parse_mention' do
    context 'with an uncached emoji' do
      it 'returns an emoji with the available data' do
        allow(bot).to receive(:emoji)
        string = '<a:foo:123>'
        emoji = bot.parse_mention(string)
        expect([emoji.name, emoji.id, emoji.animated]).to eq ['foo', 123, true]
      end
    end
  end

  describe '#handle_dispatch' do
    it 'handles GUILD_EMOJIS_UPDATE' do
      type = :GUILD_EMOJIS_UPDATE
      expect(bot).to receive(:raise_event).exactly(4).times
      bot.send(:handle_dispatch, type, dispatch_event)
    end

    context 'when handling a PRESENCE_UPDATE' do
      let(:user) { instance_double(OnyxCord::User, activities: [], id: 12_345, client_status: nil) }
      let(:guild_id) { 123_456 }
      let(:activity) { instance_double(OnyxCord::Activity, name: 'name') }
      let(:activity_fixture) { { 'name' => 'New Activity' } }
      let(:old_activity) { instance_double(OnyxCord::Activity, 'old_activity', name: 'Old Activity') }

      before do
        bot.instance_variable_set(:@users, {})
        allow(bot.instance_variable_get(:@users)).to receive(:[]).with(user.id).and_return(user)
        allow(bot).to receive(:update_presence).and_return(nil)
        allow(bot).to receive(:raise_event).with(kind_of(OnyxCord::Events::PresenceEvent))
        allow(bot).to receive(:raise_event).with(kind_of(OnyxCord::Events::PlayingEvent))
        allow(bot).to receive(:user).with(user.id).and_return(user)
        allow(bot).to receive(:server).with(guild_id).and_return(instance_double(OnyxCord::Server))
      end

      it 'raises a PlayingEvent for each new activity' do
        bot.send(:handle_dispatch, :PRESENCE_UPDATE, { 'activities' => [activity_fixture, activity_fixture], 'user' => { 'id' => user.id }, 'guild_id' => guild_id })
        expect(bot).to have_received(:raise_event).with(instance_of(OnyxCord::Events::PlayingEvent)).twice
      end

      it 'raises a PlayingEvent for each removed activity' do
        allow(user).to receive(:activities).and_return([old_activity])
        bot.send(:handle_dispatch, :PRESENCE_UPDATE, { 'activities' => [], 'user' => { 'id' => user.id }, 'guild_id' => guild_id })

        expect(bot).to have_received(:raise_event).with(instance_of(OnyxCord::Events::PlayingEvent))
      end

      it 'raises a PlayingEvent for each new and removed activity' do
        allow(user).to receive(:activities).and_return([old_activity])
        bot.send(:handle_dispatch, :PRESENCE_UPDATE, { 'activities' => [activity_fixture], 'user' => { 'id' => user.id }, 'guild_id' => guild_id })

        expect(bot).to have_received(:raise_event).with(an_instance_of(OnyxCord::Events::PlayingEvent)).twice
      end

      it 'raises a PresenceEvent when the change is not activity based' do
        bot.send(:handle_dispatch, :PRESENCE_UPDATE, { 'activities' => [], 'user' => { 'id' => user.id }, 'guild_id' => guild_id, 'status' => 'online' })

        expect(bot).to have_received(:raise_event).with(an_instance_of(OnyxCord::Events::PresenceEvent))
      end
    end

    context 'when handling a MESSAGE_CREATE event' do
      let(:channel_id) { instance_double(Integer, 'channel_id') }
      let(:channel) { instance_double(OnyxCord::Channel, recipient: author, server: nil) }
      let(:user_id) { instance_double(Integer, 'user_id') }
      let(:author) { instance_double(OnyxCord::User, id: user_id) }
      let(:message_fixture) { { 'author' => { 'id' => user_id }, 'channel_id' => channel_id } }
      let(:message) { instance_double(OnyxCord::Message, channel: channel, from_bot?: false, mentions: [], role_mentions: [], id: 123_456) }
      let(:profile) { instance_double(OnyxCord::Profile, id: 123_456, current_bot?: false) }

      before do
        allow(user_id).to receive(:to_i).and_return(user_id)
        allow(bot).to receive(:profile).and_return(profile)
        allow(bot).to receive(:channel).with(channel_id).and_return(channel)
        allow(channel).to receive(:is_a?).with(OnyxCord::Channel).and_return(true)
        allow(bot).to receive(:ignored?).with(user_id).and_return(false)
        allow(bot).to receive(:raise_event)
        allow(OnyxCord::Message).to receive(:new).and_return(message)
        allow(channel).to receive(:process_last_message_id)
      end

      it 'raises a ChannelCreateEvent if the DM channel is uncached' do
        allow(channel).to receive(:private?).and_return(true)
        allow(bot).to receive(:create_channel)

        bot.send(:handle_dispatch, :MESSAGE_CREATE, message_fixture)

        expect(bot).to have_received(:raise_event).with(instance_of(OnyxCord::Events::ChannelCreateEvent))
      end

      it 'does not raise a ChannelCreateEvent if the DM channel is cached' do
        allow(channel).to receive(:private?).and_return(true)
        bot.instance_variable_set(:@pm_channels, { user_id => channel })

        bot.send(:handle_dispatch, :MESSAGE_CREATE, message_fixture)

        expect(bot).to_not have_received(:raise_event).with(instance_of(OnyxCord::Events::ChannelCreateEvent))
      end
    end

    context 'when handling an INTERACTION_CREATE command' do
      let(:interaction_data) do
        {
          'id' => '1000',
          'application_id' => '2000',
          'type' => OnyxCord::Interaction::TYPES[:command],
          'token' => 'interaction-token',
          'version' => 1,
          'data' => {
            'id' => '3000',
            'name' => 'ping',
            'options' => []
          }
        }
      end

      it 'executes the application command through the configured event executor' do
        handled = false
        bot.instance_variable_set(:@event_executor, OnyxCord::Internal::EventExecutor::Inline.new)
        bot.instance_variable_set(:@application_commands, { ping: proc { handled = true } })
        allow(bot).to receive(:raise_event)

        bot.send(:handle_dispatch, :INTERACTION_CREATE, interaction_data)

        expect(handled).to be(true)
      end
    end
  end

  describe '#update_guild_emoji' do
    it 'removes an emoji' do
      bot.send(:update_guild_emoji, dispatch_remove)

      emojis = bot.server(server_id).emoji
      emoji = emojis[emoji_1_id]

      expect(emojis.size).to eq(1)
      expect(emoji.name).to eq(emoji_1_name)
      expect(emoji.server).to eq(server)
      expect(emoji.roles).to eq([])
    end

    it 'adds an emoji' do
      bot.send(:update_guild_emoji, dispatch_add)

      emojis = bot.server(server_id).emoji
      emoji = emojis[emoji_3_id]

      expect(emojis.size).to eq(3)
      expect(emoji.name).to eq(emoji_3_name)
      expect(emoji.server).to eq(server)
      expect(emoji.roles).to eq([])
    end

    it 'edits an emoji' do
      bot.send(:update_guild_emoji, dispatch_update)

      emojis = bot.server(server_id).emoji
      emoji = emojis[emoji_2_id]

      expect(emojis.size).to eq(2)
      expect(emoji.name).to eq(edited_emoji_name)
      expect(emoji.server).to eq(server)
      expect(emoji.roles).to eq([])
    end
  end

  describe '#send_file' do
    let(:channel) { double(:channel, resolve_id: double) }

    it 'defines original_filename when filename is passed' do
      original_filename = double(:original_filename)
      file = double(:file, original_filename: original_filename, read: true)
      new_filename = double('new filename')

      allow(OnyxCord::REST::Channel).to receive(:upload_file).and_return('{}')
      allow(OnyxCord::Message).to receive(:new)

      bot.send_file(channel, file, filename: new_filename)
      expect(file.original_filename).to eq new_filename
    end

    it 'does not define original_filename when filename is nil' do
      original_filename = double(:original_filename)
      file = double(:file, read: true, original_filename: original_filename)

      allow(OnyxCord::REST::Channel).to receive(:upload_file).and_return('{}')
      allow(OnyxCord::Message).to receive(:new)

      bot.send_file(channel, file)
      expect(file.original_filename).to eq original_filename
    end

    it 'prepends "SPOILER_" when spoiler is truthy and the filename does not start with "SPOILER_"' do
      file = double(:file, read: true)

      allow(OnyxCord::REST::Channel).to receive(:upload_file).and_return('{}')
      allow(OnyxCord::Message).to receive(:new)

      bot.send_file(channel, file, filename: 'file.txt', spoiler: true)
      expect(file.original_filename).to eq 'SPOILER_file.txt'
    end

    it 'does not prepend "SPOILER_" if the filename starts with "SPOILER_"' do
      file = double(:file, read: true, path: 'SPOILER_file.txt')

      allow(OnyxCord::REST::Channel).to receive(:upload_file).and_return('{}')
      allow(OnyxCord::Message).to receive(:new)

      bot.send_file(channel, file, spoiler: true)
      expect(file.original_filename).to eq 'SPOILER_file.txt'
    end

    it 'uses the original filename when spoiler is truthy and filename is nil' do
      file = double(:file, read: true, path: 'file.txt')

      allow(OnyxCord::REST::Channel).to receive(:upload_file).and_return('{}')
      allow(OnyxCord::Message).to receive(:new)

      bot.send_file(channel, file, spoiler: true)
      expect(file.original_filename).to eq 'SPOILER_file.txt'
    end
  end

  describe '#voice_connect' do
    it 'requires encryption' do
      channel = double(:channel, resolve_id: double)
      expect { bot.voice_connect(channel, false) }.to raise_error ArgumentError
    end
  end
end
