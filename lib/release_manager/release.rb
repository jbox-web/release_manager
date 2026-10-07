# frozen_string_literal: true

module ReleaseManager
  class Release

    CONFIGURATION_FILE  = '.release_manager.yml'
    DEFAULT_BRANCH      = 'master'
    VERSION_FILE        = 'VERSION'
    CHANGELOG_FILE      = 'CHANGELOG.md'
    CHANGELOG_FILE_JSON = 'changelog.json'
    BUMP_LEVELS         = %w[major minor patch].freeze
    RELEASE_FILES       = [VERSION_FILE, CHANGELOG_FILE, CHANGELOG_FILE_JSON].freeze

    attr_reader :current_date, :current_version, :release_date, :next_version, :bump_version, :git

    def initialize(opts = {})
      check_version_file

      @current_date       = ::Date.today.to_s
      @current_version    = Bump::Bump.current
      @release_date       = Time.now.utc.strftime('%Y%m%d%H%M%S')
      @bump_version       = opts[:bump] || 'patch'
      @next_version       = Bump::Bump.next_version(bump_version, current_version)
      @git                = Git.new(DEFAULT_BRANCH)
      @report             = Report.new(self)
      @default_config     = nil
    end

    class << self

      def release(opts = {})
        new(opts).release
      end

      def rollback
        new.rollback
      end

      def push
        new.push
      end

      def info(opts = {})
        new(opts).info
      end

    end

    def release
      check_release_preconditions
      @report.release_infos

      write_release_files

      # Commit to repo
      git.commit_release(next_version, RELEASE_FILES)
    end

    def rollback
      # Both guards protect work that a rollback would otherwise destroy: the
      # last regular commit (and the tag of the previous release) when no
      # release is pending, and local edits to the files restored below.
      raise Thor::Error, "HEAD is not the release commit of #{current_version}, nothing to roll back." \
        unless git.release_commit_at_head?(current_version)
      raise Thor::Error, 'There are uncommitted changes, commit or stash them before rolling back.' \
        unless git.clean_worktree?

      git.undo_release(current_version, RELEASE_FILES)
      puts 'Done!'
    end

    def push
      # One atomic push for the branch and this release's tag only: either
      # both land on origin or neither does, so a rejected branch can no
      # longer leave a published tag pointing at an unpublished commit.
      git.run!('push', '--atomic', '-u', 'origin', DEFAULT_BRANCH, current_version)
      puts 'Done!'
    end

    def info
      @report.info
    end

    def author
      default_config['author']
    end

    def repository_url
      default_config['repository_url']
    end

    private

      def check_release_preconditions
        # Thor::Error exits 1, so `release && push` stops on a refused release
        raise Thor::Error, @report.invalid_branch_message unless git.on_branch?
        raise Thor::Error, @report.pending_changes_message if git.pending_changes?
        # The changelog lists the commits since this tag: without it git log
        # fails and the release would record no change at all.
        unless git.tag?(current_version)
          raise Thor::Error, "Tag #{current_version} not found, can't list the changes since then."
        end

        check_configuration
      end

      # Bump would fall back on version.rb or the gemspec, while the release
      # writes VERSION: the original file would then never be bumped.
      def check_version_file
        return if File.exist?(VERSION_FILE)

        raise Thor::Error, "#{VERSION_FILE} is missing, create it with the current version."
      end

      # Every CHANGELOG.md link is built from it
      def check_configuration
        return unless repository_url.to_s.empty?

        raise Thor::Error, "#{CONFIGURATION_FILE} must define repository_url to build the CHANGELOG.md links."
      end

      # Build every file before writing the first one: a missing or invalid
      # input must stop the release with the working tree still clean.
      def write_release_files
        changelog = Changelog.new(repository_url)
        markdown  = changelog.markdown_with(changelog.entry(current_date, current_version, next_version))
        json      = changelog.json_with(next_version, release_entry)
        changelog.write(markdown: markdown, json: json, version: next_version)
      end

      def release_entry
        changes = git.subjects("#{current_version}..#{DEFAULT_BRANCH}").reverse
        changes.push("Release version #{next_version}")
        { 'author' => author, 'release_date' => release_date, 'changes' => changes }
      end

      def configuration_file
        File.join(Dir.pwd, CONFIGURATION_FILE)
      end

      def default_config
        @default_config ||=
          if File.exist?(configuration_file)
            # An empty file loads as nil
            YAML.safe_load_file(configuration_file) || {}
          else
            {}
          end
      end
  end
end
