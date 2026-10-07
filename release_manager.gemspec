# frozen_string_literal: true

require_relative 'lib/release_manager/version'

Gem::Specification.new do |s|
  s.name        = 'release_manager'
  s.version     = ReleaseManager::VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Nicolas Rodriguez']
  s.email       = ['nico@nicoladmin.fr']
  s.homepage    = 'https://github.com/jbox-web/release_manager'
  s.summary     = 'A release manager for Rails app'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.0.0'

  s.files = %x(git ls-files).split("\n")

  s.bindir      = 'exe'
  s.executables = ['release-manager']

  s.add_dependency 'bump', '>= 0.8.0'
  s.add_dependency 'paint'
  s.add_dependency 'rake'
  s.add_dependency 'thor'
  s.add_dependency 'zeitwerk'

  s.metadata['rubygems_mfa_required'] = 'true'
end
