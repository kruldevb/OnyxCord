# frozen_string_literal: true

# LIGHT-0305 — Run in a clean subprocess to verify that
# `require 'onyxcord/light'` doesn't pull in heavy models.
#
# These specs spawn a fresh Ruby process that requires only the light path and
# then inspects `$LOADED_FEATURES` and ObjectSpace for heavy classes.

RSpec.describe 'Light load isolation (LIGHT-0305, LIGHT-0120)' do
  HEAVY_CLASSES = %w[
    OnyxCord::Message OnyxCord::Channel OnyxCord::VoiceState OnyxCord::Interaction
    OnyxCord::Webhook OnyxCord::Member OnyxCord::Role OnyxCord::Server
    OnyxCord::Emoji OnyxCord::ActivitySet
  ].freeze

  HEAVY_FILES = %w[
    models/message.rb models/channel.rb models/voice_state.rb
    models/interaction.rb models/webhook.rb models/server.rb
    models/user.rb models/member.rb models/role.rb models/emoji.rb
  ].freeze

  # Ruby snippet that requires light only, then prints loaded features and
  # any heavy constants that happened to be defined.
  SNIPPET = <<~RUBY
    require 'onyxcord/light'

    puts '<FILES>'
    $LOADED_FEATURES.each { |path| puts path if path.include?('onyxcord') }
    puts '</FILES>'
    puts '<CLASSES>'
    defined_classes = []
    %w[
      Message Channel VoiceState Interaction Webhook Member Role Server Emoji ActivitySet PrimaryServer
    ].each do |name|
      present = begin
        OnyxCord.const_defined?(name, false)
      rescue StandardError
        false
      end
      defined_classes << name if present
    end
    puts defined_classes.join(',')
    puts '</CLASSES>'
  RUBY

  let(:output) do
    require 'open3'
    stdout, stderr, _status = Open3.capture3(
      { 'RUBYOPT' => '-Ilib' }, 'ruby', '-e', SNIPPET
    )
    raise "subprocess stderr:\n#{stderr}" unless stderr.empty?

    stdout
  end

  let(:loaded_files) { output.split('<FILES>').last.split('</FILES>').first.to_s }
  let(:defined_classes) { output.split('<CLASSES>').last.split('</CLASSES>').first.to_s }

  it 'does not load heavy model files' do
    HEAVY_FILES.each do |snippet|
      expect(loaded_files).not_to include(snippet),
                                  "Expected #{snippet} not to be loaded by 'onyxcord/light'"
    end
  end

  it 'does not define heavy model classes' do
    HEAVY_CLASSES.each do |qualified|
      name = qualified.split('::').last
      expect(defined_classes.split(',')).not_to include(name),
                                      "Expected #{qualified} not to be defined by 'onyxcord/light'"
    end
  end

  it 'does load onyxcord/light files' do
    expect(loaded_files).to include('light/light_bot.rb')
    expect(loaded_files).to include('light/data.rb')
    expect(loaded_files).to include('light/credential.rb')
  end
end