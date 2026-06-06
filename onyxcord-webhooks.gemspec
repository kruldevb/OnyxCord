# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'onyxcord/webhooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'onyxcord-webhooks'
  spec.version       = OnyxCord::Webhooks::VERSION
  spec.authors       = ['Gustavo S.']
  spec.email         = ['']

  spec.summary       = 'Webhook client for onyxcord'
  spec.description   = "A webhook client for OnyxCord, a Ruby Discord library based on discordrb and updated with Components V2 support."
  spec.homepage      = 'https://github.com/kruldevb/OnyxCord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z lib/onyxcord/webhooks/`.split("\x0") + ['lib/onyxcord/webhooks.rb']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rest-client', '>= 2.0.0'

  spec.required_ruby_version = '>= 3.3'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/kruldevb/OnyxCord/issues',
    'documentation_uri' => 'https://github.com/kruldevb/OnyxCord#readme',
    'source_code_uri' => 'https://github.com/kruldevb/OnyxCord',
    'rubygems_mfa_required' => 'true'
  }
end
