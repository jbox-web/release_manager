# frozen_string_literal: true

module ReleaseManager
  # Builds and writes the host application's release files: CHANGELOG.md,
  # changelog.json and VERSION.
  class Changelog

    CHANGELOG_ENTRY = /^## /

    def initialize(repository_url)
      @repository_url = repository_url
    end

    def entry(current_date, current_version, next_version)
      [
        "## [#{next_version}](#{@repository_url}/tree/#{next_version}) (#{current_date})",
        "[Full Changelog](#{@repository_url}/compare/#{current_version}...#{next_version})"
      ].join("\n")
    end

    # Inserts the entry before the first `## ` heading and copies everything
    # else verbatim: the title, any introduction, and every previous entry
    # whatever its trailing newlines. A CHANGELOG.md with no entry yet gets
    # the new one appended after its content.
    def markdown_with(entry)
      content = read_input(Release::CHANGELOG_FILE)
      first_entry = content.index(CHANGELOG_ENTRY)
      return "#{content.rstrip}\n\n#{entry}\n\n" unless first_entry

      "#{content[0...first_entry]}#{entry}\n\n#{content[first_entry..]}"
    end

    def json_with(version, release_entry)
      parse_changelog_json.merge({ version => release_entry })
    end

    def write(markdown:, json:, version:)
      File.write(Release::CHANGELOG_FILE, markdown)
      File.write(Release::CHANGELOG_FILE_JSON, "#{JSON.pretty_generate(json)}\n")
      File.write(Release::VERSION_FILE, "#{version}\n")
    end

    private

      def parse_changelog_json
        JSON.parse(read_input(Release::CHANGELOG_FILE_JSON))
      rescue JSON::ParserError
        raise Thor::Error, "#{Release::CHANGELOG_FILE_JSON} is not valid JSON, fix it before releasing."
      end

      def read_input(file)
        File.read(file, encoding: 'UTF-8')
      rescue Errno::ENOENT
        raise Thor::Error, "#{file} is missing, create it before releasing."
      end

  end
end
