# frozen_string_literal: true

require 'bundler/gem_helper'

namespace :main do
  Bundler::GemHelper.install_tasks(name: 'onyxcord')
end

task build: :'main:build'
task release: :'main:release'

# Make "build" the default task
task default: :build
