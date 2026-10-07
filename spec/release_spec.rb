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
end
