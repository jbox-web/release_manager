# ReleaseManager

Create a new release for your application, easy ;)

## Installation

Put this in your `Gemfile` :

```ruby
git_source(:github){ |repo_name| "https://github.com/#{repo_name}.git" }

gem 'release_manager', github: 'jbox-web/release_manager', branch: 'master'
```

then run `bundle install`.

## Usage

Run the commands from the root of your application, on the `master` branch:

| Command | What it does |
|---|---|
| `bundle exec release-manager info [--bump LEVEL]` | Shows the current and next version, and whether the repository is ready for a release |
| `bundle exec release-manager release [--bump LEVEL]` | Bumps `VERSION`, updates `CHANGELOG.md` and `changelog.json`, commits them and creates a signed tag |
| `bundle exec release-manager push` | Pushes `master` and the release tag to `origin`, atomically |
| `bundle exec release-manager rollback` | Undoes a release that has not been pushed yet: removes the release commit and its tag |

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
