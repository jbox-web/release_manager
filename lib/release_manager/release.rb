# frozen_string_literal: true

module ReleaseManager
  class Release

    CONFIGURATION_FILE  = '.release_manager.yml'
    DEFAULT_BRANCH      = 'master'
    VERSION_FILE        = 'VERSION'
    CHANGELOG_FILE      = 'CHANGELOG.md'
    CHANGELOG_FILE_JSON = 'changelog.json'
    CHANGELOG_ENTRY     = /^## /
    BUMP_LEVELS         = %w[major minor patch].freeze

    attr_reader :current_date, :current_version, :release_date, :next_version, :bump_version,
                :configuration_file

    def initialize(opts = {})
      # Bump would fall back on version.rb or the gemspec, while the release
      # writes VERSION: the original file would then never be bumped.
      raise Thor::Error, "#{VERSION_FILE} is missing, create it with the current version." \
        unless File.exist?(VERSION_FILE)

      @current_date       = ::Date.today.to_s
      @current_version    = Bump::Bump.current
      @release_date       = Time.now.utc.strftime('%Y%m%d%H%M%S')
      @bump_version       = opts[:bump] || 'patch'
      @next_version       = Bump::Bump.next_version(bump_version, current_version)
      @configuration_file = File.join(Dir.pwd, CONFIGURATION_FILE)
      @remote_fetched     = false
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
      # Thor::Error exits 1, so `release && push` stops on a refused release
      raise Thor::Error, invalid_branch_message unless valid_branch?
      raise Thor::Error, pending_changes_message if pending_changes?
      # The changelog lists the commits since this tag: without it git log
      # fails and the release would record no change at all.
      unless current_version_tagged?
        raise Thor::Error, "Tag #{current_version} not found, can't list the changes since then."
      end
      # Every CHANGELOG.md link is built from it
      if repository_url.to_s.empty?
        raise Thor::Error, "#{CONFIGURATION_FILE} must define repository_url to build the CHANGELOG.md links."
      end

      render_release_infos(paint(current_branch, :white))

      # Build every file before writing the first one: a missing or invalid
      # input must stop the release with the working tree still clean.
      changelog      = new_changelog(next_version_text(current_date, current_version, next_version))
      changelog_json = new_changelog_json(next_version)

      File.write(CHANGELOG_FILE, changelog)
      write_changelog_json(changelog_json)
      write_version(next_version)

      # Commit to repo
      git_commit(next_version)
    end

    def rollback
      # Both guards protect work that a rollback would otherwise destroy: the
      # last regular commit (and the tag of the previous release) when no
      # release is pending, and local edits to the files restored below.
      raise Thor::Error, "HEAD is not the release commit of #{current_version}, nothing to roll back." \
        unless release_commit_at_head?
      raise Thor::Error, 'There are uncommitted changes, commit or stash them before rolling back.' \
        unless exec_git_cmd(%w[git status --porcelain --untracked-files=no]).empty?

      git!('tag', '-d', current_version) if current_version_tagged?
      git!('reset', '--soft', 'HEAD^')
      git!('reset', '--quiet')
      git!('checkout', '--', CHANGELOG_FILE, CHANGELOG_FILE_JSON, VERSION_FILE)
      puts 'Done!'
    end

    def push
      # One atomic push for the branch and this release's tag only: either
      # both land on origin or neither does, so a rejected branch can no
      # longer leave a published tag pointing at an unpublished commit.
      git!('push', '--atomic', '-u', 'origin', DEFAULT_BRANCH, current_version)
      puts 'Done!'
    end

    def info
      puts "OK for release   : #{render_ok_for_release?}"
      render_release_infos(render_branch(current_branch))
      puts 'uncommited_files :'
      puts ok_if_empty(uncommited_files)
      puts 'staged_files :'
      puts ok_if_empty(staged_files)
      puts 'unpushed_commits :'
      puts ok_if_empty(unpushed_commits)
      puts 'unpulled_commits :'
      puts ok_if_empty(unpulled_commits)
    end

    private

      def render_release_infos(rendered_branch)
        puts "repository_url   : #{repository_url}"
        puts "author           : #{author}"
        puts "current_branch   : #{rendered_branch}"
        puts "current_date     : #{paint(current_date, :white)}"
        puts "release_date     : #{paint(release_date, :white)}"
        puts "bump_version     : #{paint(bump_version, :white)}"
        puts "current_version  : #{paint(current_version, :white)}"
        puts "next_version     : #{paint(next_version, :white)}"
        puts ''
      end

      # Inserts the entry before the first `## ` heading and copies everything
      # else verbatim: the title, any introduction, and every previous entry
      # whatever its trailing newlines. A CHANGELOG.md with no entry yet gets
      # the new one appended after its content.
      def new_changelog(entry)
        content = read_input(CHANGELOG_FILE)
        first_entry = content.index(CHANGELOG_ENTRY)
        return "#{content.rstrip}\n\n#{entry}\n\n" unless first_entry

        "#{content[0...first_entry]}#{entry}\n\n#{content[first_entry..]}"
      end

      def write_changelog_json(data)
        File.open(CHANGELOG_FILE_JSON, 'w') do |f|
          f.write JSON.pretty_generate(data)
          f.write "\n"
        end
      end

      def write_version(version)
        File.write(VERSION_FILE, "#{version}\n")
      end

      def next_version_text(current_date, current_version, next_version)
        "
          ## [#{next_version}](#{repository_url}/tree/#{next_version}) (#{current_date})
          [Full Changelog](#{repository_url}/compare/#{current_version}...#{next_version})
        ".strip.gsub(' ' * 10, '')
      end

      def git_commit(version)
        puts 'Commiting changes:'
        git!('add', VERSION_FILE, CHANGELOG_FILE, CHANGELOG_FILE_JSON)
        git!('commit', '--quiet', '-m', "Release version #{version}")
        puts 'Done!'
        puts ''

        puts 'Creating tag:'
        # Annotated and signed, with its message on the command line: a bare
        # `git tag` opens an editor when tag.gpgSign is set, and `%x()` captures
        # its output, leaving an invisible editor waiting for input.
        # A failed signature stops the release instead of printing "Done!",
        # and says how to undo the commit that already exists.
        unless system('git', 'tag', '-s', version.to_s, '-m', "Release #{version}")
          raise Thor::Error, "The release commit was created but tag #{version} could not be created. " \
                             'Fix the signing setup, then run `release-manager rollback` and release again.'
        end

        puts 'Done!'
      end

      def current_branch
        @current_branch ||= exec_git_cmd(%w[git rev-parse --abbrev-ref HEAD])
      end

      def valid_branch?
        current_branch == DEFAULT_BRANCH
      end

      def uncommited_files
        @uncommited_files ||= exec_git_cmd(%w[git diff --name-only]).split("\n")
      end

      def staged_files
        @staged_files ||= exec_git_cmd(%w[git diff --cached --name-only]).split("\n")
      end

      def unpushed_commits
        @unpushed_commits ||= remote_log("origin/#{DEFAULT_BRANCH}..#{DEFAULT_BRANCH}")
      end

      def unpulled_commits
        @unpulled_commits ||= remote_log("#{DEFAULT_BRANCH}..origin/#{DEFAULT_BRANCH}")
      end

      # Both directions are compared against a freshly fetched origin: without
      # the fetch a stale origin/master hides commits pushed by others, and a
      # missing remote used to read as "nothing to push".
      def remote_log(range)
        fetch_remote
        exec_git_cmd(%W[git log --format=oneline #{range}]).split("\n")
      end

      def fetch_remote
        return if @remote_fetched

        git!('fetch', '--quiet', 'origin', DEFAULT_BRANCH)
        @remote_fetched = true
      end

      def git_changelog
        @git_changelog ||=
          exec_git_cmd(%W[git log --format=%s #{ref_range}])
          .split("\n")
          .reverse
          .push("Release version #{next_version}")
      end

      def ref_range
        "#{current_version}..#{DEFAULT_BRANCH}"
      end

      def current_version_tagged?
        exec_git_cmd(%W[git tag --list #{current_version}]) == current_version
      end

      def release_commit_at_head?
        head         = exec_git_cmd(%w[git rev-parse HEAD])
        tag_commit   = exec_git_cmd(%W[git rev-list -n 1 #{current_version}])
        head_subject = exec_git_cmd(%w[git log -1 --format=%s])
        # No tag at all is the state a failed tag signature leaves behind
        tag_ok = current_version_tagged? ? tag_commit == head : true
        tag_ok && head_subject == "Release version #{current_version}"
      end

      # Raises Thor::Error so the CLI prints the failure and exits 1 instead of
      # carrying on with the next step.
      def git!(*args)
        return if system('git', *args)

        raise Thor::Error, "`git #{args.join(' ')}` failed, stopping."
      end

      def exec_git_cmd(args)
        cmd = args.join(' ')
        out = %x(#{cmd})
        # Git prints UTF-8, but the capture is labelled with the locale's
        # encoding, which is US-ASCII under LANG=C and breaks commit subjects.
        out.force_encoding(Encoding::UTF_8).strip
      end

      def invalid_branch_message
        <<~MSG
          Invalid branch to create tag : '#{paint(current_branch, :bold)}'.
          You must be on '#{paint(DEFAULT_BRANCH, :bold)}' branch to create a new release.
          Exiting...
        MSG
      end

      def pending_changes_message
        <<~MSG
          There are pending changes :
          * staged_files     : #{staged_files}
          * uncommited_files : #{uncommited_files}
          * unpushed_commits : #{unpushed_commits}
          * unpulled_commits : #{unpulled_commits}

          Commit them or stash them before creating a new release.
          Exiting...
        MSG
      end

      def new_changelog_json(next_version)
        current_changelog = parse_changelog_json
        release_entry     = { 'author' => author, 'release_date' => release_date, 'changes' => git_changelog }
        current_changelog.merge({ next_version => release_entry })
      end

      def parse_changelog_json
        JSON.parse(read_input(CHANGELOG_FILE_JSON))
      rescue JSON::ParserError
        raise Thor::Error, "#{CHANGELOG_FILE_JSON} is not valid JSON, fix it before releasing."
      end

      def read_input(file)
        File.read(file, encoding: 'UTF-8')
      rescue Errno::ENOENT
        raise Thor::Error, "#{file} is missing, create it before releasing."
      end

      def pending_changes?
        staged_files.any? || uncommited_files.any? || unpushed_commits.any? || unpulled_commits.any?
      end

      def ok_for_release?
        valid_branch? && !pending_changes?
      end

      def render_ok_for_release?
        ok_for_release? ? paint('✓', :green) : paint('✗', :red)
      end

      def ok_if_empty(files)
        if files.empty?
          paint YAML.dump(files), :green
        else
          paint YAML.dump(files), :red
        end
      end

      def render_branch(branch)
        valid_branch? ? paint(branch, :green) : paint(branch, :red)
      end

      def author
        default_config['author']
      end

      def repository_url
        default_config['repository_url']
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

      def paint(string, *color)
        Paint[string, *color]
      end
  end
end
