# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager --bump' do
  let(:app) { create_host_repo }

  %w[release info].each do |command|
    it "rejects an unknown value for #{command}" do
      result = run_cli(app, command, '--bump', 'minr')

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include("Expected '--bump' to be one of major, minor, patch; got minr")
      expect(sh!(app, 'git', 'tag', '--list')).to eq('1.0.0')
      expect(read_file(app, 'VERSION')).to eq("1.0.0\n")
    end
  end
end
