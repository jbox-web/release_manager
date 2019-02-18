# frozen_string_literal: true

require 'date'
require 'yaml'
require 'bump'
require 'colorize'
require 'thor'

require 'zeitwerk'

class CustomInflector < Zeitwerk::Inflector
  def camelize(basename, _abspath)
    case basename
    when 'cli'
      'CLI'
    else
      super
    end
  end
end

loader = Zeitwerk::Loader.new
loader.inflector = CustomInflector.new
loader.push_dir(__dir__)
loader.setup

module ReleaseManager
  def self.start_cli(args)
    ReleaseManager::CLI.start(ARGV)
  end
end
