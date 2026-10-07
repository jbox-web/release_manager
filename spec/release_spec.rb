# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager release' do
  let(:app) { create_host_repo }
  let(:today) { Date.today.to_s }

  context 'when the repository is ready for a release' do
    it 'exits successfully' do
      result = run_cli(app, 'release', '--bump', 'minor')

      expect(result.status).to be_success, result.stderr
    end

    it 'writes the next version to VERSION' do
      run_cli(app, 'release', '--bump', 'minor')

      expect(read_file(app, 'VERSION')).to eq("1.1.0\n")
    end

    it 'prepends the new entry to CHANGELOG.md' do
      run_cli(app, 'release', '--bump', 'minor')

      expect(read_file(app, 'CHANGELOG.md')).to eq(<<~MD)
        # Change Log

        ## [1.1.0](https://example.test/app/tree/1.1.0) (#{today})
        [Full Changelog](https://example.test/app/compare/1.0.0...1.1.0)

        ## [1.0.0](https://example.test/app/tree/1.0.0) (2026-01-01)
        [Full Changelog](https://example.test/app/compare/0.9.0...1.0.0)

      MD
    end

    it 'records the release in changelog.json' do
      run_cli(app, 'release', '--bump', 'minor')

      expect(JSON.parse(read_file(app, 'changelog.json'))).to match(
        '1.1.0' => {
          'author' => 'Jane Doe',
          'release_date' => a_string_matching(/\A\d{14}\z/),
          'changes' => ['Add feature', 'Release version 1.1.0']
        }
      )
    end

    it 'commits the three release files' do
      run_cli(app, 'release', '--bump', 'minor')

      expect(sh!(app, 'git', 'log', '-1', '--format=%s')).to eq('Release version 1.1.0')
      expect(sh!(app, 'git', 'show', '--name-only', '--format=', 'HEAD').split("\n"))
        .to contain_exactly('CHANGELOG.md', 'VERSION', 'changelog.json')
      expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
    end

    it 'creates an annotated, signed tag on the release commit' do
      run_cli(app, 'release', '--bump', 'minor')

      expect(sh!(app, 'git', 'cat-file', '-t', '1.1.0')).to eq('tag')
      expect(sh!(app, 'git', 'rev-parse', '1.1.0^{commit}')).to eq(sh!(app, 'git', 'rev-parse', 'HEAD'))
      expect { sh!(app, 'git', 'tag', '-v', '1.1.0') }.not_to raise_error
    end
  end

  context 'when the repository is not ready for a release' do
    it 'exits 1 on another branch than master' do
      sh!(app, 'git', 'checkout', '-q', '-b', 'feature')

      result = run_cli(app, 'release')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include("You must be on 'master' branch to create a new release.")
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
    end

    it 'exits 1 when there are uncommitted changes' do
      write_file(app, 'feature.txt', "changed\n")

      result = run_cli(app, 'release')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include('There are pending changes')
      expect(result.stderr).to include('uncommited_files : ["feature.txt"]')
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
    end

    it 'exits 1 when the current version has no tag' do
      sh!(app, 'git', 'tag', '-d', '1.0.0')

      result = run_cli(app, 'release')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr)
        .to include("Tag 1.0.0 not found, can't list the changes since then.")
      expect(sh!(app, 'git', 'tag', '--list')).to eq('')
      expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
    end

    it 'exits 1 when there is no origin remote' do
      sh!(app, 'git', 'remote', 'remove', 'origin')

      result = run_cli(app, 'release')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include('`git fetch --quiet origin master` failed')
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
    end

    it 'exits 1 when origin has commits not pulled yet' do
      other = File.join(File.dirname(app), 'other')
      sh!(File.dirname(app), 'git', 'clone', '-q', 'origin.git', other)
      commit_feature(other, name: 'remote.txt', subject: 'Remote work')
      sh!(other, 'git', 'push', '-q', 'origin', 'master')

      result = run_cli(app, 'release')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to match(/unpulled_commits : \["\h+ Remote work"\]/)
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
    end
  end

  context 'when changelog.json cannot be used' do
    {
      'is not valid JSON' => 'not json',
      'is missing' => nil
    }.each do |problem, content|
      it "fails before writing anything when it #{problem}" do
        app = create_host_repo(changelog_json: content)

        result = run_cli(app, 'release', '--bump', 'minor')

        expect(result.status.exitstatus).to eq(1)
        expect(result.stderr).to include("changelog.json #{problem}")
        expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
        expect(read_file(app, 'VERSION')).to eq("1.0.0\n")
      end
    end
  end

  context 'when git refuses the release commit' do
    before do
      hook = File.join(app, '.git', 'hooks', 'pre-commit')
      File.write(hook, "#!/bin/sh\nexit 1\n")
      File.chmod(0o755, hook)
    end

    it 'fails without creating the tag' do
      result = run_cli(app, 'release', '--bump', 'minor')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stdout).not_to include('Creating tag')
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
      expect(sh!(app, 'git', 'log', '-1', '--format=%s')).to eq('Add feature')
    end
  end
end
