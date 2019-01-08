# frozen_string_literal: true

require_relative 'lib/release_manager/version'

Gem::Specification.new do |s|
  s.name        = 'release_manager'
  s.version     = ReleaseManager::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Nicolas Rodriguez']
  s.email       = ['nicoladmin@free.fr']
  s.homepage    = 'https://github.com/jbox-web/release_manager'
  s.summary     = %q{A release manager for Rails app}
  s.license     = 'MIT'

  s.files       = `git ls-files`.split("\n")
  s.executables = ['release_manager']

  s.add_runtime_dependency 'bump'
  s.add_runtime_dependency 'colorize'
  s.add_runtime_dependency 'rake'
  s.add_runtime_dependency 'thor'
end
