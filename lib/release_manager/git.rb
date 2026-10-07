# frozen_string_literal: true

module ReleaseManager
  # Every git command a release runs, in the host application's directory.
  class Git

    def initialize(branch)
      @branch           = branch
      @remote_fetched   = false
      @current_branch   = nil
      @uncommited_files = nil
      @staged_files     = nil
      @unpushed_commits = nil
      @unpulled_commits = nil
    end

    def current_branch
      @current_branch ||= capture(%w[rev-parse --abbrev-ref HEAD])
    end

    def on_branch?
      current_branch == @branch
    end

    def uncommited_files
      @uncommited_files ||= capture(%w[diff --name-only]).split("\n")
    end

    def staged_files
      @staged_files ||= capture(%w[diff --cached --name-only]).split("\n")
    end

    def unpushed_commits
      @unpushed_commits ||= remote_log("origin/#{@branch}..#{@branch}")
    end

    def unpulled_commits
      @unpulled_commits ||= remote_log("#{@branch}..origin/#{@branch}")
    end

    def pending_changes?
      staged_files.any? || uncommited_files.any? || unpushed_commits.any? || unpulled_commits.any?
    end

    def clean_worktree?
      capture(%w[status --porcelain --untracked-files=no]).empty?
    end

    def tag?(name)
      capture(%W[tag --list #{name}]) == name
    end

    def tag_commit(name)
      capture(%W[rev-list -n 1 #{name}])
    end

    def head
      capture(%w[rev-parse HEAD])
    end

    def head_subject
      capture(%w[log -1 --format=%s])
    end

    def subjects(range)
      capture(%W[log --format=%s #{range}]).split("\n")
    end

    def commit_release(version, files)
      puts 'Commiting changes:'
      run!('add', *files)
      run!('commit', '--quiet', '-m', "Release version #{version}")
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

    def release_commit_at_head?(version)
      # No tag at all is the state a failed tag signature leaves behind
      tag_ok = tag?(version) ? tag_commit(version) == head : true
      tag_ok && head_subject == "Release version #{version}"
    end

    def undo_release(version, files)
      run!('tag', '-d', version) if tag?(version)
      run!('reset', '--soft', 'HEAD^')
      run!('reset', '--quiet')
      run!('checkout', '--', *files)
    end

    # Raises Thor::Error so the CLI prints the failure and exits 1 instead of
    # carrying on with the next step.
    def run!(*args)
      return if system('git', *args)

      raise Thor::Error, "`git #{args.join(' ')}` failed, stopping."
    end

    private

      # Both directions are compared against a freshly fetched origin: without
      # the fetch a stale origin/master hides commits pushed by others, and a
      # missing remote used to read as "nothing to push".
      def remote_log(range)
        fetch_remote
        capture(%W[log --format=oneline #{range}]).split("\n")
      end

      def fetch_remote
        return if @remote_fetched

        run!('fetch', '--quiet', 'origin', @branch)
        @remote_fetched = true
      end

      def capture(args)
        # argv form, no shell: each argument reaches git as is. stderr is not
        # captured, so git's own error messages still reach the terminal.
        out, _status = Open3.capture2('git', *args)
        # Git prints UTF-8, but the capture is labelled with the locale's
        # encoding, which is US-ASCII under LANG=C and breaks commit subjects.
        out.force_encoding(Encoding::UTF_8).strip
      end

  end
end
