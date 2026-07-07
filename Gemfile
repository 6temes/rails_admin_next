# frozen_string_literal: true

source "https://rubygems.org"

gem "net-smtp", require: false
gem "rails"
gem "turbo-rails"

group :development, :test do
  gem "pry", ">= 0.9"
end

group :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "cancancan", "~> 3.0"
  gem "cuprite", "!= 0.15.1"
  gem "database_cleaner-active_record", ">= 2.0", require: false
  gem "factory_bot", ">= 4.2", "!= 6.4.5"
  gem "generator_spec", ">= 0.8"
  gem "image_processing", ">= 1.2"
  gem "pundit"
  gem "rspec-expectations", "!= 3.8.3"
  gem "rspec-rails", ">= 4.0.0.beta2"
  gem "rspec-retry"
  gem "ruby-vips", ">= 2.1"
  gem "simplecov", ">= 0.9", require: false
  gem "simplecov-lcov", require: false
  gem "standard", ">= 1.35.1", require: false

  # Windows does not include zoneinfo files, so bundle the tzinfo-data gem
  gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]
  gem "warden"
end

group :active_record do
  gem "paper_trail", ">= 12.0"

  platforms :ruby, :mswin, :mingw, :x64_mingw do
    gem "mysql2", ">= 0.3.14"
    gem "pg", ">= 1.0.0"
    gem "sqlite3", ">= 1.3.0"
  end
end

gemspec
