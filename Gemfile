# frozen_string_literal: true

source "https://rubygems.org"

gem "net-smtp", require: false
gem "rails"
gem "turbo-rails"

group :development, :test do
  gem "pry"
end

group :test do
  gem "brakeman", require: false
  gem "cancancan", "~> 3.0"
  gem "cuprite"
  gem "database_cleaner-active_record", require: false
  gem "factory_bot"
  gem "generator_spec"
  gem "image_processing"
  gem "pundit"
  gem "rspec-rails"
  gem "rspec-retry"
  gem "ruby-vips"
  gem "standard", require: false
  gem "warden"
  # Capybara's own default server is puma, which is not in this bundle; spec_helper selects
  # webrick instead. It arrives as a transitive of ferrum, so declare what the suite runs on
  # rather than borrowing someone else's dependency.
  gem "webrick"

  # Windows does not ship zoneinfo files.
  gem "tzinfo-data", platforms: %i[windows]
end

# The dummy app boots with `Bundler.require(*Rails.groups, :active_record)`, so this group is
# loaded in every environment — that is what puts the adapter on the load path outside :test.
group :active_record do
  gem "mysql2"
  gem "paper_trail"
  gem "pg"
  gem "sqlite3"
end

gemspec
