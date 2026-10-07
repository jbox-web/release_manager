# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'release-manager release, CHANGELOG.md handling' do
  let(:today) { Date.today.to_s }
  let(:new_entry) do
    <<~MD
      ## [1.1.0](https://example.test/app/tree/1.1.0) (#{today})
      [Full Changelog](https://example.test/app/compare/1.0.0...1.1.0)

    MD
  end

  def release_with(changelog)
    app = create_host_repo(changelog: changelog)
    result = run_cli(app, 'release', '--bump', 'minor')
    expect(result.status).to be_success, result.stderr
    read_file(app, 'CHANGELOG.md')
  end

  it 'keeps every previous entry when the file ends with a single newline' do
    previous = <<~MD
      ## [1.0.0](https://example.test/app/tree/1.0.0) (2026-01-01)
      [Full Changelog](https://example.test/app/compare/0.9.0...1.0.0)

      - feature A

      ## [0.9.0](https://example.test/app/tree/0.9.0) (2025-01-01)
      - old entry
    MD

    expect(release_with("# Change Log\n\n#{previous}")).to eq("# Change Log\n\n#{new_entry}#{previous}")
  end

  it 'keeps the text written between the title and the first entry' do
    intro = "# Change Log\n\nAll notable changes are listed here.\n\n"
    previous = "## [1.0.0](https://example.test/app/tree/1.0.0) (2026-01-01)\n- feature A\n"

    expect(release_with("#{intro}#{previous}")).to eq("#{intro}#{new_entry}#{previous}")
  end

  it 'adds the first entry to a CHANGELOG.md that has none yet' do
    expect(release_with("# Change Log\n")).to eq("# Change Log\n\n#{new_entry}")
  end
end
