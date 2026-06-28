# frozen_string_literal: true

require_relative 'lib/onyxcord/webhooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'onyxcord-webhooks'
  spec.version       = OnyxCord::Webhooks::VERSION
  spec.authors       = ['Gustavo Silva']
  spec.email         = ['gustavosilva8kt@gmail.com']

  spec.summary       = '[DEPRECATED] Webhook client for onyxcord — now bundled into the onyxcord gem'
  spec.description   = "This gem is deprecated. Webhooks are now included in the onyxcord gem. Install 'onyxcord' instead."
  spec.homepage      = 'https://github.com/kruldevb/OnyxCord'
  spec.license       = 'MIT'

  spec.files         = ['lib/onyxcord/webhooks.rb', 'lib/onyxcord/webhooks/version.rb']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # This gem now simply depends on the main onyxcord gem
  spec.add_dependency 'onyxcord', "~> #{OnyxCord::Webhooks::VERSION}"

  spec.required_ruby_version = '>= 3.4'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/kruldevb/OnyxCord/issues',
    'documentation_uri' => 'https://github.com/kruldevb/OnyxCord#readme',
    'source_code_uri' => 'https://github.com/kruldevb/OnyxCord',
    'rubygems_mfa_required' => 'true'
  }

  spec.post_install_message = <<~MSG
    ⚠️  onyxcord-webhooks is DEPRECATED.
    Webhooks are now bundled into the 'onyxcord' gem.
    Please update your Gemfile:
      gem 'onyxcord', '~> 2.0'
    and remove 'onyxcord-webhooks'.
  MSG
end
