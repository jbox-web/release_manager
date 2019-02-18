# frozen_string_literal: true

require 'date'
require 'yaml'
require 'bump'
require 'colorize'
require 'thor'

module ReleaseManager
  require 'release_manager/version'
  require 'release_manager/release'
  require 'release_manager/cli'

  def self.start_cli(args)
    ReleaseManager::CLI.start(ARGV)
  end
end
