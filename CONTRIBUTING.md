# Contributing

In the spirit of [free software][free-sw], **everyone** is encouraged to help improve
this project.

[free-sw]: http://www.fsf.org/licensing/essays/free-sw.html

Here are some ways _you_ can contribute:

- by triaging bug reports
- by writing or editing documentation
- by writing specifications
- by writing code (**no patch is too small**: fix typos, add comments, clean up
  inconsistent whitespace)
- by refactoring code
- by fixing [issues][]
- by reviewing patches
- by suggesting new features

[issues]: https://github.com/6temes/rails_admin_next/issues

## Development

RailsAdminNext targets a **single supported runtime** — Ruby 4.0.5, Rails ~> 8.1,
ActiveRecord, and an importmap + Propshaft asset pipeline. There is **no multi-ORM,
multi-bundler, or multi-Rails build matrix**, and **no Appraisal**: the suite runs against
one Gemfile with no `yarn build` step.

The gem has no application of its own; it is developed and tested against the embedded
host app at `spec/dummy_app/`.

### Prerequisites

To run the suite you need:

- **Google Chrome** — the `js: true` specs run in headless Chrome driven by Cuprite/Ferrum.
- **libvips** — required by the image-field specs (ActiveStorage's `:vips` variant processor;
  the `ruby-vips` gem dlopens the libvips shared library).

Example installation on macOS using Homebrew:

```bash
brew install vips
brew install --cask google-chrome
```

Example installation on Ubuntu:

```bash
sudo apt-get update -y && sudo apt-get install -y libvips-dev
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get install -y ./google-chrome-stable_current_amd64.deb
```

### Setup

```bash
bundle install

# Provision the dummy app database (database.yml is generated, not committed):
cd spec/dummy_app
bundle exec rake rails_admin:prepare_ci_env db:create db:schema:load
cd -
```

There is no `yarn install`/`yarn build` step — the engine serves browser-native ESM and
CSS over importmap + Propshaft, so the assets need no compilation before the suite runs.

### Running tests

```bash
bundle exec rspec                                       # full suite (sqlite3)
bundle exec rspec spec/integration/actions/show_spec.rb # single file
bundle exec rspec spec/integration/actions/show_spec.rb:42  # single example by line
```

The test run reads two environment variables:

- `CI_DB_ADAPTER` — `sqlite3` (default), `postgresql`, or `mysql2`. It is consumed by the
  `rails_admin:prepare_ci_env` rake task, which (re)writes `spec/dummy_app/config/database.yml`.
  Re-run the provision step above after changing it.
- `RAILS_ENV` — `test`.

```bash
# Run against PostgreSQL (re-provision the database first, then run the suite):
cd spec/dummy_app && CI_DB_ADAPTER=postgresql bundle exec rake rails_admin:prepare_ci_env db:create db:schema:load && cd -
CI_DB_ADAPTER=postgresql bundle exec rspec
```

There is no `spec/rails_helper.rb`: every spec does `require 'spec_helper'`, and
`spec/spec_helper.rb` boots `spec/dummy_app/config/environment`.

### Lint and security gates

CI gates every push and pull request on the following checks. Run them locally before
opening a pull request:

```bash
bundle exec standardrb                 # Ruby style
bundle exec brakeman -A --no-pager     # static security analysis
bundle exec bundler-audit check --update  # gem advisory audit
npx --yes prettier@2.8.8 --check .     # JS/CSS formatting (no package.json; pinned via npx)
```

`bundle exec rake` runs the default task — the spec suite followed by Standard. It does
**not** run Prettier, Brakeman, or bundler-audit, so run those separately.

The importmap pins the engine self-hosts are a [Dependabot blind spot](SECURITY.md);
they are audited by hand on the cadence documented in [SECURITY.md](SECURITY.md).

## Submitting an issue

If you're confident that you've found a bug, please [open an issue][issues] after checking
that it hasn't already been reported. Include the steps to reproduce, a stack trace, and
your gem version, Ruby version, and operating system. Ideally, a bug report includes a
pull request with failing specs.

## Submitting a pull request

1. [Fork the repository.][fork]
2. Create a branch.
3. Add specs for your unimplemented feature or bug fix.
4. Implement your feature or bug fix.
5. Run `bundle exec rake`. If anything fails, return to step 4.
6. Run the lint and security gates above.
7. Add, commit, and push your changes.
8. [Submit a pull request.][pr]

[fork]: https://docs.github.com/en/get-started/quickstart/fork-a-repo
[pr]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
