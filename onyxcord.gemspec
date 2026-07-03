# frozen_string_literal: true

require_relative 'lib/onyxcord/version'

Gem::Specification.new do |spec|
  spec.name          = 'onyxcord'
  spec.version       = OnyxCord::VERSION
  spec.authors       = ['Gustavo Silva']
  spec.email         = ['gustavosilva8kt@gmail.com']

  spec.summary       = 'Discord API for Ruby with Components V2 support'
  spec.description   = 'OnyxCord is a Ruby Discord API library with Components V2, modern modals, raw-first events, and community support: https://discord.gg/Jy2tpCUtzM.'
  spec.homepage      = 'https://github.com/kruldevb/OnyxCord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").select { |f| File.file?(f) }.reject { |f| f.match(%r{^(test|spec|features|examples)/}) }
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

  # Modern async runtime & networking
  spec.add_dependency 'async', '>= 2.0', '< 3'
  spec.add_dependency 'async-http', '>= 0.75', '< 1'
  spec.add_dependency 'async-websocket', '>= 0.26', '< 1'

  # HTTP client (modern, HTTP/2, persistent connections)
  spec.add_dependency 'httpx', '>= 1.0', '< 2'

  # Fast JSON parsing
  spec.add_dependency 'oj', '>= 3.0', '< 4'

  # Smart LRU caching
  spec.add_dependency 'lru_redux', '>= 1.0', '< 2'

  # Observability/profiling
  spec.add_dependency 'OnyxProfiler', '~> 0.1'

  # Core dependencies
  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'mime-types', '~> 3.0'

  # Voice support
  spec.add_dependency 'ffi', '>= 1.9.24', '< 2'
  spec.add_dependency 'opus-ruby', '>= 0', '< 2'

  spec.required_ruby_version = '>= 3.4'

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
