# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

require_relative 'support/host_repo'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.include HostRepo
  config.after { remove_host_repos }
end
