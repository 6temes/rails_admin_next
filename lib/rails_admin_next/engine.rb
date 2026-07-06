# frozen_string_literal: true

require "action_cable/engine"
require "geared_pagination"
require "rails"
require "rails_admin_next"
require "rails_admin_next/extensions/url_for_extension"
require "rails_admin_next/version"
require "stimulus-rails"
require "turbo-rails"

module RailsAdminNext
  class Engine < Rails::Engine
    isolate_namespace RailsAdminNext

    attr_accessor :importmap

    config.action_dispatch.rescue_responses["RailsAdminNext::ActionNotAllowed"] = :forbidden

    initializer "RailsAdminNext load UrlForExtension" do
      RailsAdminNext::Engine.routes.singleton_class.prepend(RailsAdminNext::Extensions::UrlForExtension)
    end

    initializer "RailsAdminNext reload config in development" do |app|
      config.initializer_path = app.root.join("config/initializers/rails_admin_next.rb")

      unless Rails.application.config.cache_classes
        ActiveSupport::Reloader.before_class_unload do
          RailsAdminNext::Config.reload!
        end

        reloader = app.config.file_watcher.new([config.initializer_path], []) do
          # Do nothing, ActiveSupport::Reloader will trigger class_unload! anyway
        end

        app.reloaders << reloader
        app.reloader.to_run do
          reloader.execute_if_updated { require_unload_lock! }
        end
        reloader.execute
      end
    end

    initializer "RailsAdminNext assets", group: :all do |app|
      # Propshaft auto-registers the engine's app/assets (stylesheets + fonts); the browser-native
      # ESM modules live under src/ — a non-conventional asset dir — so push it explicitly.
      app.config.assets.paths << RailsAdminNext::Engine.root.join("src")

      # The engine draws its OWN importmap (distinct from the host's config/importmap.rb), rendered
      # inline — with the request CSP nonce — by app/views/layouts/rails_admin_next/_head.html.erb.
      # A host that ships config/importmap.rails_admin.rb has it appended last, so it can override
      # the `rails_admin_next` entrypoint pin (to add its own ActiveStorage/locales/custom UI) or add pins.
      self.importmap = Importmap::Map.new.draw(RailsAdminNext::Engine.root.join("config/importmap.rails_admin.rb"))
      host_importmap = app.root.join("config/importmap.rails_admin.rb")
      importmap.draw(host_importmap) if host_importmap.exist?

      # Invalidate the cached importmap JSON in development when an engine ESM file changes.
      importmap.cache_sweeper(watches: RailsAdminNext::Engine.root.join("src"))
      app.reloader.to_run { RailsAdminNext::Engine.importmap.cache_sweeper.execute_if_updated } unless app.config.cache_classes

      # SRI/integrity is optional hardening: its value is cross-origin/CDN assets, which
      # self-hosting same-origin already removes. Enable it only when the host opts in via
      # config.assets.integrity_hash_algorithm (requires propshaft >= 1.2).
      importmap.enable_integrity! if app.config.assets.try(:integrity_hash_algorithm).present?
    end

    # Check for required middlewares, users may forget to use them in Rails API mode
    config.after_initialize do |app|
      has_session_store = app.config.middleware.to_a.any? do |m|
        m.klass.try(:<=, ActionDispatch::Session::AbstractStore) ||
          m.klass.try(:<=, ActionDispatch::Session::AbstractSecureStore) ||
          m.klass.name =~ /^ActionDispatch::Session::/
      end
      loaded = app.config.middleware.to_a.map(&:name)
      required = %w[ActionDispatch::Cookies ActionDispatch::Flash Rack::MethodOverride]
      missing = required - loaded
      unless missing.empty? && has_session_store
        configs = missing.map { |m| "config.middleware.use #{m}" }
        configs << "config.middleware.use #{app.config.session_store.try(:name) || "ActionDispatch::Session::CookieStore"}, #{app.config.session_options}" unless has_session_store
        raise <<~ERROR
          Required middlewares for RailsAdminNext are not added
          To fix this, add

            #{configs.join("\n  ")}

          to config/application.rb.
        ERROR
      end
    end
  end
end
