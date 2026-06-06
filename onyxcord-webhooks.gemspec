# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'onyxcord/webhooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'onyxcord-webhooks'
  spec.version       = OnyxCord::Webhooks::VERSION
  spec.authors       = %w[meew0 swarley]
  spec.email         = ['']

  spec.summary       = 'Webhook client for onyxcord'
  spec.description   = "A client for Discord's webhooks to fit alongside [onyxcord](https://rubygems.org/gems/onyxcord)."
  spec.homepage      = 'https://github.com/shardlab/onyxcord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z lib/onyxcord/webhooks/`.split("\x0") + ['lib/onyxcord/webhooks.rb']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rest-client', '>= 2.0.0'

  spec.required_ruby_version = '>= 3.3'
  spec.metadata = {
    'rubygems_mfa_required' => 'true'
  }
end
