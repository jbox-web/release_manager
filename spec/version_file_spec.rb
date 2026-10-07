# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager without a VERSION file' do
  let(:app) do
    create_host_repo.tap do |dir|
      FileUtils.mkdir_p(File.join(dir, 'lib', 'app'))
      write_file(dir, 'lib/app/version.rb', "module App\n  VERSION = '1.0.0'\nend\n")
      sh!(dir, 'git', 'rm', '-q', 'VERSION')
      sh!(dir, 'git', 'add', 'lib/app/version.rb')
      sh!(dir, 'git', 'commit', '-q', '-m', 'Move the version to lib')
      sh!(dir, 'git', 'push', '-q')
    end
  end

  %w[release info].each do |command|
    it "#{command} refuses to run instead of reading another version file" do
      result = run_cli(app, command)

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include('VERSION is missing')
      expect(File).not_to exist(File.join(app, 'VERSION'))
      expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
    end
  end
end
