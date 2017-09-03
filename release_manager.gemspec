# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'release_manager/version'

Gem::Specification.new do |s|
  s.name        = 'release_manager'
  s.version     = ReleaseManager::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Nicolas Rodriguez']
  s.email       = ['nicoladmin@free.fr']
  s.homepage    = 'https://github.com/jbox-web/release_manager'
  s.summary     = %q{A release manager for Rails app}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'rake'
  s.add_dependency 'thor'
  s.add_dependency 'bump'
  s.add_dependency 'colorize'
end
