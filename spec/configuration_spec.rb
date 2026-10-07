# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager configuration' do
  {
    'is missing' => nil,
    'is empty' => '',
    'has no repository_url' => "author: Jane Doe\n"
  }.each do |problem, config|
    context "when .release_manager.yml #{problem}" do
      let(:app) { create_host_repo(config: config) }

      it 'refuses the release before writing anything' do
        result = run_cli(app, 'release')

        expect(result.status.exitstatus).to eq(1)
        expect(result.stderr).to include('.release_manager.yml must define repository_url')
        expect(sh!(app, 'git', 'status', '--porcelain')).to eq('')
      end

      it 'still displays info' do
        result = run_cli(app, 'info')

        expect(result.status).to be_success, result.stderr
        expect(result.stdout).to include("repository_url   : \n")
      end
    end
  end
end
