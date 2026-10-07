# ReleaseManager

[![CI](https://github.com/jbox-web/release_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/jbox-web/release_manager/actions/workflows/ci.yml)

Create a new release for your application, easy ;)

## Installation

Put this in your `Gemfile` :

```ruby
git_source(:github){ |repo_name| "https://github.com/#{repo_name}.git" }

gem 'release_manager', github: 'jbox-web/release_manager', branch: 'master'
```

then run `bundle install`, and generate the binstub:

```sh
bundle binstubs release_manager
```

It creates `bin/release-manager`, which pins the gem version from your `Gemfile.lock`.
Ruby 3.3 or later is required.

## Usage

Run the commands from the root of your application, on the `master` branch:

| Command | What it does |
|---|---|
| `bin/release-manager info [--bump LEVEL]` | Shows the current and next version, and whether the repository is ready for a release |
| `bin/release-manager release [--bump LEVEL]` | Bumps `VERSION`, updates `CHANGELOG.md` and `changelog.json`, commits them and creates a signed tag |
| `bin/release-manager push` | Pushes `master` and the release tag to `origin`, atomically |
| `bin/release-manager rollback` | Removes the release commit and its tag locally; meant for a release not pushed yet, since nothing is removed from `origin` |

`LEVEL` is `major`, `minor` or `patch` (default). Any other value is rejected.

`release` refuses to run, and exits 1, unless you are on `master` with no staged, unstaged,
unpushed or unpulled changes (`origin` is fetched first), and the current version is tagged.
The tag is created with `git tag -s`, so git must be configured to sign tags.

## Files expected in your application

| File | Content |
|---|---|
| `VERSION` | The current version, e.g. `1.0.0`. Required by every command. |
| `CHANGELOG.md` | The new entry is inserted before the first `## ` heading; the rest of the file is kept as is. |
| `changelog.json` | A JSON object, `{}` at first. Each release adds its `author`, `release_date` and `changes` (the commit subjects since the previous tag). |
| `.release_manager.yml` | `repository_url` (required by `release`, used for the `CHANGELOG.md` links) and `author`. |

Example `.release_manager.yml`:

```yaml
author: Jane Doe
repository_url: https://github.com/acme/app
```
