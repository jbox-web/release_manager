# frozen_string_literal: true

require 'date'
require 'json'
require 'yaml'
require 'bump'
require 'paint'
require 'thor'

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module ReleaseManager
  def self.start_cli(args)
    ReleaseManager::Cli.start(args)
  end
end
