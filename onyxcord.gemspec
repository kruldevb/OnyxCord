# frozen_string_literal: true

require_relative 'lib/onyxcord/version'
require_relative 'lib/onyxcord/webhooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'onyxcord'
  spec.version       = OnyxCord::VERSION
  spec.authors       = ['Gustavo Silva']
  spec.email         = ['gustavosilva8kt@gmail.com']

  spec.summary       = 'Discord API for Ruby with Components V2 support'
  spec.description   = 'A Ruby implementation of the Discord API based on discordrb, updated for OnyxCord with raw-first core, modern modals, and Components V2.'
  spec.homepage      = 'https://github.com/kruldevb/OnyxCord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|examples|lib/onyxcord/webhooks)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/kruldevb/OnyxCord/issues',
    'changelog_uri' => 'https://github.com/kruldevb/OnyxCord/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://github.com/kruldevb/OnyxCord#readme',
    'source_code_uri' => 'https://github.com/kruldevb/OnyxCord',
    'rubygems_mfa_required' => 'true'
  }
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'ffi', '>= 1.9.24'
  spec.add_dependency 'opus-ruby'
  spec.add_dependency 'rest-client', '>= 2.0.0'
  spec.add_dependency 'websocket-client-simple', '>= 0.9.0'

  spec.add_dependency 'onyxcord-webhooks', "~> #{OnyxCord::Webhooks::VERSION}"

  spec.required_ruby_version = '>= 3.3'

  spec.add_development_dependency 'bundler', '>= 1.10', '< 5'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'redcarpet', '~> 3.5' # YARD markdown formatting
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.6.0'
  spec.add_development_dependency 'rspec-prof', '~> 0.0.7'
  spec.add_development_dependency 'rubocop', '~> 1.77.0'
  spec.add_development_dependency 'rubocop-performance', '~> 1.25.0'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7.0'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'yard', '~> 0.9.37'
end
