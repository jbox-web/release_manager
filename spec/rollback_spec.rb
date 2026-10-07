# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager rollback' do
  let(:app) { create_host_repo }

  context 'when HEAD is the release commit' do
    before { run_cli(app, 'release', '--bump', 'minor') }

    it 'removes the release commit and its tag' do
      result = run_cli(app, 'rollback')

      expect(result.status).to be_success, result.stderr
      expect(sh!(app, 'git', 'log', '-1', '--format=%s')).to eq('Add feature')
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
    end

    it 'restores the release files' do
      run_cli(app, 'rollback')

      expect(read_file(app, 'VERSION')).to eq("1.0.0\n")
      expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
    end

    it 'refuses when the working tree has uncommitted changes' do
      write_file(app, 'CHANGELOG.md', "# Change Log\n\nwork in progress\n")

      result = run_cli(app, 'rollback')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include('uncommitted changes')
      expect(read_file(app, 'CHANGELOG.md')).to eq("# Change Log\n\nwork in progress\n")
      expect(sh!(app, 'git', 'log', '-1', '--format=%s')).to eq('Release version 1.1.0')
    end
  end

  context 'when HEAD is not a release commit' do
    it 'refuses without touching history or tags' do
      result = run_cli(app, 'rollback')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include('HEAD is not the release commit of 1.0.0')
      expect(sh!(app, 'git', 'log', '-1', '--format=%s')).to eq('Add feature')
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
      expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
    end
  end
end
