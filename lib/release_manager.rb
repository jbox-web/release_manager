# frozen_string_literal: true

require 'date'
require 'yaml'
require 'bump'
require 'colorize'
require 'thor'

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module ReleaseManager
  def self.start_cli(args)
    ReleaseManager::Cli.start(ARGV)
  end
end
