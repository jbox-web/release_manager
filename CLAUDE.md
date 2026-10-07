# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A small Thor CLI gem (`release-manager`) that cuts releases of a **host application**: it is added to
the host app's `Gemfile` (from GitHub, by tag) and run from that app's root. All file and git
operations target `Dir.pwd`, never this gem's own repository.

## Commands

Ruby is pinned in `mise.toml`, which also wraps the commands as tasks:

- Install dependencies: `mise run dev:deps` (`bundle install`)
- Lint: `mise run dev:lint` (`bin/rubocop`, bounded to 180s; config in `.rubocop.yml`, `bin/*` excluded,
  target Ruby 3.3, max line length 110)
- Specs: `mise run dev:spec` (`bin/rspec`, bounded to 600s); one example: `bin/rspec spec/release_spec.rb:16`
- Build the gem: `mise run release:build` (`bin/rake build`; only the `bundler/gem_tasks` tasks exist)
- Run the CLI locally: `bundle exec exe/release-manager <release|rollback|push|info> [--bump major|minor|patch]`

The specs are end-to-end: `spec/support/host_repo.rb` builds a throwaway host app (bare `origin` + `master`
clone) and runs the real executable in a subprocess. Git is isolated from the developer's config through
`GIT_CONFIG_GLOBAL` (generated file with a per-run SSH signing key) and `GIT_CONFIG_NOSYSTEM`.

CI (`.github/workflows/ci.yml`) runs the same mise tasks: lint, gem build, specs on the pinned Ruby
(Linux amd64/arm64, macOS arm64) and on the other maintained Rubies through `MISE_RUBY_VERSION`.

`Gemfile.lock` is git-ignored, so gem versions are whatever the local lockfile resolved. The gemspec
builds its file list from `git ls-files`: a tracked file missing from disk makes `gem build` fail.

## Architecture

- `exe/release-manager` → `ReleaseManager.start_cli` → `ReleaseManager::Cli` (Thor) → class methods
  on `ReleaseManager::Release`, which builds an instance per command and orchestrates three
  collaborators: `Git` (every git command), `Changelog` (builds and writes `CHANGELOG.md`,
  `changelog.json` and `VERSION`) and `Report` (all printed output and refusal messages). Files are
  autoloaded by Zeitwerk (`Zeitwerk::Loader.for_gem`), so new constants must follow the file-naming
  convention.
- `Release#initialize` computes everything up front: current version via `Bump::Bump.current`
  (read from the host app's `VERSION` file), next version via `Bump::Bump.next_version`. Thor rejects
  a `--bump` value outside `Release::BUMP_LEVELS` before any of this runs.
- Host app contract — files expected at the host app root:
  - `VERSION` — required by every command (Bump's fallback to `version.rb` or the gemspec is
    refused), rewritten with the next version.
  - `CHANGELOG.md` — the new entry is inserted before the first `## ` heading; everything else
    (title, introduction, previous entries) is copied verbatim.
  - `changelog.json` — must exist and be valid JSON; a new key per version is merged in with
    `author`, `release_date` and `changes` (commit subjects from `<current_version>..master`).
  - `.release_manager.yml` — provides `author` and `repository_url`; `release` refuses to run
    without `repository_url` (`info` still works).
- `release` fetches `origin/master` and refuses to run unless on `master` (`DEFAULT_BRANCH`,
  hardcoded) with no staged, unstaged, unpushed or unpulled changes. It builds the new files
  before writing any of them, commits them and creates a signed, annotated tag named after the
  bare version (no `v` prefix).
- `rollback` only runs when HEAD is the release commit of the current version, tagged by it or left
  untagged by a failed signature, and the working tree is clean; it then deletes the tag if any and
  soft-resets `HEAD^`.
- `push` pushes `master` and the current version tag to `origin` in one `git push --atomic`.
- Refusals raise `Thor::Error` (`exit_on_failure?` is true, so the CLI exits 1). Git queries go through
  `Git#capture` (`Open3.capture2` in argv form, output relabelled as UTF-8); mutations go through
  `Git#run!`, which raises `Thor::Error` when the command fails.

## Conventions

- `Style/CommandLiteral` enforces `%x()` over backticks.
- Private methods are indented one level under `private` (`Layout/IndentationConsistency:
  indented_internal_methods`).
- The gem's own version lives in `lib/release_manager/version.rb` (`VERSION::MAJOR/MINOR/TINY/PRE`),
  unrelated to the host app's `VERSION` file.
