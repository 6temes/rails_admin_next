# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("dummy_app/config/environment", __dir__)

require "rspec/rails"
require "factory_bot"
require "factories"
require "policies"
require "database_cleaner/active_record"
require "orm/active_record"
require "paper_trail/frameworks/rspec" if defined?(PaperTrail)

Dir[File.expand_path("support/**/*.rb", __dir__),
  File.expand_path("shared_examples/**/*.rb", __dir__)].sort.each { |f| require f }

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.default_url_options[:host] = "example.com"

Rails.backtrace_cleaner.remove_silencers!

require "capybara/cuprite"
Capybara.javascript_driver = :cuprite
Capybara.register_driver(:cuprite) do |app|
  # js_errors makes an unhandled error or promise rejection fail the example. With no bundler,
  # no type checker and no JS linter in CI, that is the only thing exercising src/rails_admin.
  Capybara::Cuprite::Driver.new(app, js_errors: true, logger: ConsoleLogger)
end
# Not the Puma default: puma is not in this bundle, and webrick is (via ferrum). Capybara names
# this line itself as the remedy when it cannot load puma.
Capybara.server = :webrick

RailsAdminNext.setup_all_extensions

RSpec.configure do |config|
  config.disable_monkey_patching!

  # Finalize the engine's routes so its dynamically-drawn helpers (new_path, edit_path, …)
  # are materialized on the url_helpers module before it is included. Without this, a request
  # spec that runs before any other (order-dependent) hits `undefined method 'new_path'`.
  #
  # This also leaves the routes reloader marked loaded, so nothing later in the suite draws
  # routes from whatever the action registry happens to hold at that moment — see the heal
  # below for what that would cost. `reload_routes!` would draw and then clear the flag again,
  # re-arming the lazy path. The method is :nodoc: rather than private, and has been stable
  # since Rails 7.1.
  Rails.application.reload_routes_unless_loaded
  config.include RailsAdminNext::Engine.routes.url_helpers

  # The engine draws its routes from the GLOBAL action registry (config/routes.rb reads
  # RailsAdminNext::Config::Actions.all). A spec that evaluates `config.actions { ... }` leaves
  # that registry reduced, and if the engine's route set is redrawn inside that window the
  # dashboard/new/edit/... routes vanish; Config.reset (below) restores the registry but NOT the
  # routes, so every later request spec fails with `undefined method 'dashboard_path'` — an
  # order-dependent wipeout. Heal by re-drawing the
  # routes whenever the engine route set no longer matches its boot-time shape — fingerprinted
  # by sorted route names, not size: a count can't see same-size drift where one action's route
  # swaps for another's.
  engine_route_names = RailsAdminNext::Engine.routes.routes.map { |route| route.name.to_s }.sort

  config.include Warden::Test::Helpers

  config.include Capybara::DSL, type: :request
  config.include Capybara::RSpecMatchers, type: :request

  config.verbose_retry = true
  config.display_try_failure_messages = true
  # A js example that clicks a submit control gets control back before the server has
  # answered, so reading the database next can read the row as it was. Assert something the
  # response puts on the page first — the flash, an injected option label — and let Capybara
  # wait on that. Nothing below catches the mistake: the read succeeds, returns the old value,
  # and the retry re-runs an example that is only wrong when the runner is loaded.
  config.around :each, :js do |example|
    example.run_with_retry retry: 2
  end
  config.retry_callback = proc do |example|
    example.metadata[:retry] = 6 if [Ferrum::DeadBrowserError, Ferrum::NoExecutionContextError, Ferrum::TimeoutError].include?(example.exception.class)
    if example.metadata[:js]
      attempt = 0
      begin
        Capybara.reset!
      rescue Ferrum::TimeoutError, Ferrum::NoExecutionContextError
        attempt += 1
        raise if attempt >= 5

        retry
      end
    end
  end

  config.before do |example|
    DatabaseCleaner.strategy = example.metadata[:js] ? :deletion : :transaction

    DatabaseCleaner.start
    RailsAdminNext::Config.reset
    Rails.application.reload_routes! if RailsAdminNext::Engine.routes.routes.map { |route| route.name.to_s }.sort != engine_route_names
    # Headless Chrome inherits the host OS appearance, and the admin honors
    # prefers-color-scheme (light-dark() tokens) — pin js specs to the light
    # scheme so rendering assertions are machine-independent. Dark rendering
    # is not covered by the automated suite.
    RailsAdminNext::Config.color_scheme = :light if example.metadata[:js]
  end

  # Restoring the locale matters because a spec that leaves I18n.locale dirty (edit_spec's I18n
  # cases) bleeds into any later locale-sensitive spec. This runs after the example body, so
  # specs that set their own locale via `around` are unaffected.
  config.after(:each) do
    I18n.locale = I18n.default_locale
    Warden.test_reset!
    DatabaseCleaner.clean
  end
end
