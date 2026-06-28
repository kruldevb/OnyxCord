# frozen_string_literal: true

require_relative 'lib/onyxcord/webhooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'onyxcord-webhooks'
  spec.version       = OnyxCord::Webhooks::VERSION
  spec.authors       = ['Gustavo Silva']
  spec.email         = ['gustavosilva8kt@gmail.com']

  spec.summary       = 'Webhook client for onyxcord'
  spec.description   = "Webhook client for OnyxCord with Components V2 support and community support: https://discord.gg/Jy2tpCUtzM."
  spec.homepage      = 'https://github.com/kruldevb/OnyxCord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z lib/onyxcord/webhooks/`.split("\x0") + ['lib/onyxcord/webhooks.rb']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rest-client', '>= 2.0.0', '< 3'

  spec.required_ruby_version = '>= 3.3'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/kruldevb/OnyxCord/issues',
    'documentation_uri' => 'https://github.com/kruldevb/OnyxCord#readme',
    'source_code_uri' => 'https://github.com/kruldevb/OnyxCord',
    'rubygems_mfa_required' => 'true'
  }
end
