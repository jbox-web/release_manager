# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager push' do
  let(:app) { create_host_repo }
  let(:origin) { File.join(File.dirname(app), 'origin.git') }

  def remote_refs
    sh!(app, 'git', 'ls-remote', '--refs', 'origin').split("\n").map { |line| line.split("\t").last }
  end

  before { run_cli(app, 'release', '--bump', 'minor') }

  it 'pushes master and the release tag' do
    result = run_cli(app, 'push')

    expect(result.status).to be_success, result.stderr
    expect(sh!(origin, 'git', 'rev-parse', 'master')).to eq(sh!(app, 'git', 'rev-parse', 'HEAD'))
    expect(remote_refs).to include('refs/tags/1.1.0')
  end

  it 'leaves the other local tags alone' do
    sh!(app, 'git', 'tag', 'experiment')

    run_cli(app, 'push')

    expect(remote_refs).not_to include('refs/tags/experiment')
  end

  context 'when origin rejects master' do
    before do
      other = File.join(File.dirname(app), 'other')
      sh!(File.dirname(app), 'git', 'clone', '-q', origin, other)
      commit_feature(other, name: 'remote.txt', subject: 'Remote work')
      sh!(other, 'git', 'push', '-q', 'origin', 'master')
    end

    it 'exits 1 without publishing the tag' do
      result = run_cli(app, 'push')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include('`git push --atomic -u origin master 1.1.0` failed')
      expect(remote_refs).not_to include('refs/tags/1.1.0')
    end
  end
end
