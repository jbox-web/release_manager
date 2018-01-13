module ReleaseManager
  class Release

    CONFIGURATION_FILE = '.release_manager.yml'.freeze
    DEFAULT_BRANCH     = 'master'.freeze
    VERSION_FILE       = 'VERSION'.freeze
    CHANGELOG_FILE     = 'CHANGELOG.md'.freeze
    CHANGELOG_FILE_YML = 'changelog.yml'.freeze
    CHANGELOG_REGEX    =  /(##.*\[Full Changelog\].*\n\n)/m

    attr_reader :current_date, :current_version, :next_version, :bump_version, :configuration_file

    def initialize(opts = {})
      @current_date       = ::Date.today.to_s
      @current_version    = Bump::Bump.current
      @bump_version       = opts[:bump] || 'patch'
      @bump_version       = 'patch' if !%w[major minor patch].include?(bump_version)
      @next_version       = Bump::Bump.send(:next_version, current_version, bump_version)
      @configuration_file = File.join(Dir.pwd, CONFIGURATION_FILE)
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
      # Check if current branch is valid for creating tag
      unless valid_branch?
        render_invalid_branch_message
        return
      end

      # There should be not pending changes
      if pending_changes?
        render_pending_changes_message
        return
      end

      puts "repository_url   : #{repository_url}"
      puts "current_branch   : #{current_branch.white}"
      puts "current_date     : #{current_date.white}"
      puts "bump_version     : #{bump_version.white}"
      puts "current_version  : #{current_version.white}"
      puts "next_version     : #{next_version.white}"
      puts ''

      # Get all versions from CHANGELOG.md
      versions = get_versions

      # Add our new version
      versions = versions.unshift(next_version_text(current_date, current_version, next_version))

      # Write the new CHANGELOG.md
      write_changelog(versions)

      # Regenerate changelog.yml file
      update_changelog_yml(next_version)

      # Write the new VERSION
      write_version(next_version)

      # Commit to repo
      git_commit(next_version)
    end

    def rollback
      %x[git tag -d #{current_version}]
      %x[git reset --soft HEAD^]
      %x[git reset]
      %x[git checkout #{CHANGELOG_FILE}]
      %x[git checkout #{CHANGELOG_FILE_YML}]
      %x[git checkout #{VERSION_FILE}]
      puts 'Done!'
    end

    def push
      %x[git push -u origin #{DEFAULT_BRANCH}]
      %x[git push -u origin --tags]
      puts 'Done!'
    end

    def info
      puts "OK for release   : #{render_ok_for_release?}"
      puts "repository_url   : #{repository_url}"
      puts "current_branch   : #{render_branch(current_branch)}"
      puts "current_date     : #{current_date.white}"
      puts "bump_version     : #{bump_version.white}"
      puts "current_version  : #{current_version.white}"
      puts "next_version     : #{next_version.white}"
      puts ''
      puts "uncommited_files :"
      puts ok_if_empty(uncommited_files)
      puts "staged_files :"
      puts ok_if_empty(staged_files)
      puts "unpushed_commits :"
      puts ok_if_empty(unpushed_commits)
    end

    private

      def get_versions
        versions = File.read(CHANGELOG_FILE).split(CHANGELOG_REGEX)[1].split("\n\n")
        versions = versions.reject { |v| v == "\n" }
        versions
      end

      def write_changelog(versions)
        File.open(CHANGELOG_FILE, 'w') do |f|
          f.write "# Change Log"
          f.write "\n\n"
          versions.each do |b|
            f.write b
            f.write "\n\n"
          end
        end
      end

      def write_changelog_yml(data)
        File.open(CHANGELOG_FILE_YML, 'w') do |f|
          f.write data
        end
      end

      def write_version(version)
        File.open(VERSION_FILE, 'w') do |f|
          f.write "#{version}\n"
        end
      end

      def next_version_text(current_date, current_version, next_version)
        """
          ## [#{next_version}](#{repository_url}/tree/#{next_version}) (#{current_date})
          [Full Changelog](#{repository_url}/compare/#{current_version}...#{next_version})
        """.strip.gsub(' ' * 10, '')
      end

      def git_commit(version)
        puts 'Commiting changes:'
        %x[git add #{VERSION_FILE} #{CHANGELOG_FILE} #{CHANGELOG_FILE_YML}]
        %x[git commit -m 'Release version #{version}']
        puts 'Done!'
        puts ''

        puts 'Creating tag:'
        %x[git tag #{version}]
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
        @unpushed_commits ||= exec_git_cmd(%W[git log --format=oneline origin/#{DEFAULT_BRANCH}..#{DEFAULT_BRANCH}]).split("\n")
      end

      def git_changelog
        @git_changelog ||= exec_git_cmd(%W[git log --format=%s #{ref_range}]).split("\n").reverse.push("Release version #{next_version}")
      end

      def ref_range
        "#{current_version}...master"
      end

      def exec_git_cmd(args)
        cmd = args.join(' ')
        out = %x[#{cmd}]
        out.strip
      end

      def render_invalid_branch_message
        puts "Invalid branch to create tag : '#{current_branch.bold}'."
        puts "You must be on '#{DEFAULT_BRANCH.bold}' branch to create a new release."
        puts "Exiting..."
      end

      def render_pending_changes_message
        puts "There are pending changes :"
        puts "* staged_files     : #{staged_files}"
        puts "* uncommited_files : #{uncommited_files}"
        puts "* unpushed_commits : #{unpushed_commits}"
        puts ""
        puts "Commit them or stash them before creating a new release."
        puts "Exiting..."
      end

      def update_changelog_yml(next_version)
        current_changelog = YAML.load(File.read(CHANGELOG_FILE_YML))
        next_changelog    = current_changelog.merge({ next_version => git_changelog })
        write_changelog_yml(next_changelog.to_yaml)
      end

      def pending_changes?
        staged_files.any? || uncommited_files.any? || unpushed_commits.any?
      end

      def ok_for_release?
        valid_branch? && !pending_changes?
      end

      def render_ok_for_release?
        ok_for_release? ? '✓'.green : '✗'.red
      end

      def ok_if_empty(files)
        if files.empty?
          YAML::dump(files).green
        else
          YAML::dump(files).red
        end
      end

      def render_branch(branch)
        valid_branch? ? branch.green : branch.red
      end

      def repository_url
        default_config['repository_url']
      end

      def default_config
        @default_config ||=
          if File.exist?(configuration_file)
            YAML.load(File.read(configuration_file))
          else
            { 'repository_url' => '' }
          end
      end

  end
end
