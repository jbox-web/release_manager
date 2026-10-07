# frozen_string_literal: true

# Builds a throwaway host application (a bare `origin` plus a `master` clone)
# and runs the real `release-manager` executable against it, in a subprocess,
# exactly as a user would. Git is isolated from the developer's configuration:
# GIT_CONFIG_GLOBAL points to a generated file and the system file is ignored,
# so a personal `tag.gpgSign` or signing key never leaks into the specs.
module HostRepo
  EXE      = File.expand_path('../../exe/release-manager', __dir__)
  GEMFILE  = File.expand_path('../../Gemfile', __dir__)
  AUTHOR   = 'Jane Doe'
  REPO_URL = 'https://example.test/app'

  DEFAULT_CHANGELOG = <<~MD
    # Change Log

    ## [1.0.0](https://example.test/app/tree/1.0.0) (2026-01-01)
    [Full Changelog](https://example.test/app/compare/0.9.0...1.0.0)

  MD

  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

  class << self

    # One SSH key pair and one git configuration for the whole run: generating
    # a key per example would dominate the suite's run time.
    def toolbox
      @toolbox ||= build_toolbox
    end

    private

      def build_toolbox
        dir = Dir.mktmpdir('release-manager-toolbox')
        at_exit { FileUtils.rm_rf(dir) }
        key = File.join(dir, 'key')
        system('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'spec', '-f', key, exception: true)
        signers = File.join(dir, 'allowed_signers')
        File.write(signers, "spec@example.test #{File.read("#{key}.pub")}")
        gitconfig = File.join(dir, 'gitconfig')
        File.write(gitconfig, gitconfig_content(key, signers))
        { 'gitconfig' => gitconfig }
      end

      def gitconfig_content(key, signers)
        <<~INI
          [user]
            name = #{AUTHOR}
            email = spec@example.test
            signingkey = #{key}.pub
          [gpg]
            format = ssh
          [gpg "ssh"]
            allowedSignersFile = #{signers}
          [init]
            defaultBranch = master
          [advice]
            detachedHead = false
        INI
      end

  end

  def git_env
    {
      'GIT_CONFIG_GLOBAL' => HostRepo.toolbox['gitconfig'],
      'GIT_CONFIG_NOSYSTEM' => '1',
      'BUNDLE_GEMFILE' => GEMFILE
    }
  end

  # Creates the host repository and returns the path of its working copy.
  # VERSION 1.0.0 is committed and tagged, followed by one feature commit, and
  # everything is pushed: the state in which a release is legitimate.
  def create_host_repo(changelog: DEFAULT_CHANGELOG, changelog_json: "{}\n", config: default_config)
    root = Dir.mktmpdir('release-manager-host')
    @host_roots = (@host_roots || []) << root
    origin = File.join(root, 'origin.git')
    app    = File.join(root, 'app')
    sh!(root, 'git', 'init', '-q', '--bare', origin)
    sh!(root, 'git', 'init', '-q', app)
    seed_host_files(app, changelog, changelog_json, config)
    commit_feature(app)
    sh!(app, 'git', 'remote', 'add', 'origin', origin)
    sh!(app, 'git', 'push', '-q', '-u', 'origin', 'master')
    app
  end

  def seed_host_files(app, changelog, changelog_json, config)
    write_file(app, 'VERSION', "1.0.0\n")
    write_file(app, 'CHANGELOG.md', changelog) if changelog
    write_file(app, 'changelog.json', changelog_json) if changelog_json
    write_file(app, '.release_manager.yml', config) if config
    sh!(app, 'git', 'add', '--all')
    sh!(app, 'git', 'commit', '-q', '-m', 'Initial commit')
    sh!(app, 'git', 'tag', '1.0.0')
  end

  def commit_feature(app, name: 'feature.txt', subject: 'Add feature')
    write_file(app, name, "#{subject}\n")
    sh!(app, 'git', 'add', name)
    sh!(app, 'git', 'commit', '-q', '-m', subject)
  end

  def remove_host_repos
    (@host_roots || []).each { |root| FileUtils.rm_rf(root) }
  end

  def default_config
    "author: #{AUTHOR}\nrepository_url: #{REPO_URL}\n"
  end

  # Runs the CLI in `dir`. ANSI colors are stripped so expectations read as text.
  def run_cli(dir, *args, env: {})
    stdout, stderr, status = Open3.capture3(git_env.merge(env), RbConfig.ruby, EXE, *args, chdir: dir)
    Result.new(stdout: strip_ansi(stdout), stderr: strip_ansi(stderr), status: status)
  end

  # Runs a command in `dir`, raises if it fails, returns its stripped stdout.
  def sh!(dir, *cmd)
    stdout, stderr, status = Open3.capture3(git_env, *cmd, chdir: dir)
    raise "#{cmd.join(' ')} failed in #{dir}:\n#{stderr}" unless status.success?

    stdout.strip
  end

  def write_file(dir, name, content)
    File.write(File.join(dir, name), content)
  end

  def read_file(dir, name)
    File.read(File.join(dir, name), encoding: 'UTF-8')
  end

  def strip_ansi(text)
    text.gsub(/\e\[[0-9;]*m/, '')
  end
end
