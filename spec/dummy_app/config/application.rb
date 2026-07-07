# frozen_string_literal: true

require File.expand_path("boot", __dir__)

require "action_controller/railtie"
require "action_mailer/railtie"

require "active_record/railtie"

require "active_storage/engine"
require "action_text/engine"

require "propshaft"
require "importmap-rails"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups, :active_record)

module DummyApp
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.load_defaults 8.1
    config.eager_load_paths = (config.try(:all_eager_load_paths) || config.eager_load_paths).reject { |p| p =~ %r{/app/([^/]+)} && !%w[controllers jobs locales mailers active_record].include?(Regexp.last_match[1]) }
    config.eager_load_paths += %W[#{config.root}/app/eager_loaded]
    config.autoload_paths += %W[#{config.root}/lib]
    config.i18n.load_path += Dir[Rails.root.join("app", "locales", "*.{rb,yml}").to_s]
    config.active_record.time_zone_aware_types = %i[datetime time]
    config.active_record.yaml_column_permitted_classes = [Symbol]
    config.active_storage.service = :local if defined?(ActiveStorage)
    config.active_storage.variant_processor = :vips if defined?(ActiveStorage)
  end
end
