# frozen_string_literal: true

module ReleaseManager
  # Everything a release prints: the summary, the `info` checklist and the
  # refusal messages.
  class Report

    def initialize(release)
      @release = release
      @git     = release.git
    end

    def info
      puts "OK for release   : #{render_ok_for_release}"
      release_infos(render_branch)
      {
        'uncommited_files' => @git.uncommited_files,
        'staged_files' => @git.staged_files,
        'unpushed_commits' => @git.unpushed_commits,
        'unpulled_commits' => @git.unpulled_commits
      }.each do |label, items|
        puts "#{label} :"
        puts ok_if_empty(items)
      end
    end

    def release_infos(rendered_branch = paint(@git.current_branch, :white))
      release_lines(rendered_branch).each { |line| puts line }
      puts ''
    end

    def invalid_branch_message
      <<~MSG
        Invalid branch to create tag : '#{paint(@git.current_branch, :bold)}'.
        You must be on '#{paint(Release::DEFAULT_BRANCH, :bold)}' branch to create a new release.
        Exiting...
      MSG
    end

    def pending_changes_message
      <<~MSG
        There are pending changes :
        * staged_files     : #{@git.staged_files}
        * uncommited_files : #{@git.uncommited_files}
        * unpushed_commits : #{@git.unpushed_commits}
        * unpulled_commits : #{@git.unpulled_commits}

        Commit them or stash them before creating a new release.
        Exiting...
      MSG
    end

    private

      def release_lines(rendered_branch)
        [
          "repository_url   : #{@release.repository_url}",
          "author           : #{@release.author}",
          "current_branch   : #{rendered_branch}",
          "current_date     : #{paint(@release.current_date, :white)}",
          "release_date     : #{paint(@release.release_date, :white)}",
          "bump_version     : #{paint(@release.bump_version, :white)}",
          "current_version  : #{paint(@release.current_version, :white)}",
          "next_version     : #{paint(@release.next_version, :white)}"
        ]
      end

      def render_ok_for_release
        ok = @git.on_branch? && !@git.pending_changes?
        ok ? paint('✓', :green) : paint('✗', :red)
      end

      def render_branch
        paint(@git.current_branch, @git.on_branch? ? :green : :red)
      end

      def ok_if_empty(files)
        paint YAML.dump(files), (files.empty? ? :green : :red)
      end

      def paint(string, *color)
        Paint[string, *color]
      end

  end
end
