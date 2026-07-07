# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAdminNext, type: :request do
  subject { page }

  before do
    RailsAdminNext::Config.authenticate_with { warden.authenticate! scope: :user }
    RailsAdminNext::Config.current_user_method(&:current_user)
    login_as User.create(
      email: "username@example.com",
      password: "password"
    )
  end

  # A common mistake for translators is to forget to change the YAML file's
  # root key from en to their own locale (as people tend to use the English
  # file as template for a new translation).
  describe "localization" do
    it "defaults to English" do
      RailsAdminNext.config.included_models = []
      visit dashboard_path

      is_expected.to have_content("Site Administration")
      is_expected.to have_content("Dashboard")
    end
  end

  describe "html head" do
    before { visit dashboard_path }

    # NOTE: the [href^="/assets... syntax matches the start of a value, so Propshaft's
    # asset digests don't throw the match off.
    it "loads the engine stylesheet through Propshaft" do
      is_expected.to have_selector('head link[href^="/assets/rails_admin"][href$=".css"]', visible: false)
    end

    # The importmap+Propshaft pipeline emits the inline importmap + module-preload tags
    # and the module entrypoint — and no sprockets/webpack/vite per-file script tags.
    it "delivers JavaScript via the inline importmap and module tags" do
      is_expected.to have_selector('head script[type="importmap"]', visible: false)
      is_expected.to have_selector('head link[rel="modulepreload"][href^="/assets/rails_admin"]', visible: false)
      is_expected.to have_selector('head script[type="module"]', visible: false)
      is_expected.to have_no_selector('head script[src^="/assets/rails_admin"][src$=".js"]', visible: false)
      is_expected.to have_no_selector('head script[src*="packs"]', visible: false)
      is_expected.to have_no_selector('head script[src*="/vite/"]', visible: false)
    end

    # The color-scheme meta is what every light-dark() token pair in the engine CSS resolves
    # against; it must precede the stylesheet link so the scheme is known before first paint.
    describe "color scheme meta" do
      it "defaults to auto (light dark) and precedes the stylesheet", :aggregate_failures do
        is_expected.to have_selector('head meta[name="color-scheme"][content="light dark"]', visible: false)
        expect(page.html.index('name="color-scheme"')).to be < page.html.index('rel="stylesheet"')
      end

      it "renders a pinned scheme" do
        RailsAdminNext.config do |config|
          config.color_scheme = :dark
        end
        visit dashboard_path
        is_expected.to have_selector('head meta[name="color-scheme"][content="dark"]', visible: false)
      end
    end
  end

  describe "navbar css class" do
    it "is set by default" do
      expect(RailsAdminNext.config.navbar_css_classes).to eq(%w[navbar-dark bg-primary border-bottom])
    end

    it "can be configured" do
      RailsAdminNext.config do |config|
        config.navbar_css_classes = %w[navbar-light border-bottom]
      end
      visit dashboard_path
      is_expected.to have_css("nav.navbar.navbar-light.border-bottom")
    end
  end

  describe "sidebar navigation", js: true do
    it "is collapsible" do
      visit dashboard_path
      is_expected.to have_css(".sidebar details[open] > summary", text: "Navigation")
      is_expected.to have_css(".sidebar .nav-link", text: "Players")
      find(".sidebar summary", text: "Navigation").click
      is_expected.to have_css(".sidebar details:not([open]) > summary", text: "Navigation")
      is_expected.not_to have_css(".sidebar .nav-link", text: "Players")
    end

    it "persists over a page transition" do
      visit dashboard_path
      find(".sidebar summary", text: "Navigation").click
      is_expected.to have_css(".sidebar details:not([open]) > summary", text: "Navigation")
      find(".player_links .show a").trigger("click")
      is_expected.to have_content "List of Players"
      is_expected.to have_css(".sidebar details:not([open]) > summary", text: "Navigation")
      is_expected.not_to have_css(".sidebar .nav-link", text: "Players")
    end

    it "toggles with the keyboard" do
      visit dashboard_path
      summary = find(".sidebar summary", text: "Navigation")
      # Focus without clicking (Cuprite's send_keys clicks the node to focus it,
      # which would itself toggle the disclosure), then send real key events.
      page.execute_script("arguments[0].focus()", summary)

      page.driver.browser.keyboard.type(:enter)
      is_expected.to have_css(".sidebar details:not([open]) > summary", text: "Navigation")
      is_expected.not_to have_css(".sidebar .nav-link", text: "Players")

      page.driver.browser.keyboard.type(:space)
      is_expected.to have_css(".sidebar details[open] > summary", text: "Navigation")
      is_expected.to have_css(".sidebar .nav-link", text: "Players")
    end

    it "collapses groups independently" do
      RailsAdminNext.config Comment do
        navigation_label "Commentables"
      end

      visit dashboard_path
      find(".sidebar summary", text: "Navigation").click
      is_expected.to have_css(".sidebar details:not([open]) > summary", text: "Navigation")
      is_expected.to have_css(".sidebar details[open] > summary", text: "Commentables")
      is_expected.to have_css(".sidebar .nav-link", text: "Comments")
      is_expected.not_to have_css(".sidebar .nav-link", text: "Players")
    end
  end

  describe "_current_user" do # https://github.com/railsadminteam/rails_admin/issues/549
    it "is accessible from the list view" do
      RailsAdminNext.config Player do
        list do
          field :name do
            visible do
              bindings[:view]._current_user.email == "username@example.com"
            end
          end

          field :team do
            visible do
              bindings[:view]._current_user.email == "foo@example.com"
            end
          end
        end
      end

      visit index_path(model_name: "player")
      is_expected.to have_selector(".header.name_field")
      is_expected.not_to have_selector(".header.team_field")
    end
  end

  describe "secondary navigation" do
    it "has Gravatar image" do
      visit dashboard_path
      is_expected.to have_selector('ul.navbar-nav img[src*="gravatar.com"]')
    end

    it "does not show Gravatar when user doesn't have email method" do
      allow_any_instance_of(User).to receive(:respond_to?).and_return(true)
      allow_any_instance_of(User).to receive(:respond_to?).with(:email).and_return(false)
      visit dashboard_path
      is_expected.not_to have_selector("ul.nav.pull-right li img")
    end

    it "does not cause error when email is nil" do
      allow_any_instance_of(User).to receive(:email).and_return(nil)
      visit dashboard_path
      is_expected.to have_selector("body.rails_admin")
    end

    it "shows a log out link" do
      visit dashboard_path
      is_expected.to have_content "Log out"
    end

    it "has bg-danger class on log out link" do
      visit dashboard_path
      is_expected.to have_selector(".bg-danger")
    end

    it "has links for actions which are marked as show_in_navigation" do
      I18n.backend.store_translations(
        :en, admin: {actions: {
          shown_in_navigation: {menu: "Look this"}
        }}
      )
      RailsAdminNext.config do |config|
        config.actions do
          dashboard do
            show_in_navigation false
          end
          root :shown_in_navigation, :dashboard do
            action_name :dashboard
            show_in_navigation true
          end
        end
      end

      visit dashboard_path
      is_expected.not_to have_css ".root_links li", text: "Dashboard"
      is_expected.to have_css ".root_links li", text: "Look this"
    end
  end

  describe "CSRF protection" do
    before do
      allow_any_instance_of(ActionController::Base).to receive(:protect_against_forgery?).and_return(true)
    end

    it "is enforced" do
      visit new_path(model_name: "league")
      fill_in "league[name]", with: "National league"
      find('input[name="authenticity_token"]', visible: false).set("invalid token")
      expect { click_button "Save" }.to raise_error ActionController::InvalidAuthenticityToken
    end
  end

  describe "Turbo Drive", js: true do
    let(:player) { FactoryBot.create :player }

    it "does not trigger JS errors by going away from and back to RailsAdminNext" do
      visit show_path(model_name: "player", id: player.id)
      click_link "Show in app"
      click_link "Back to admin"
      is_expected.to have_content "Details for Player"
    end

    it "triggers rails_admin.dom_ready right after a validation error" do
      visit edit_path(model_name: "player", id: player.id)
      fill_in "player[name]", with: "on steroids"
      find_button("Save").trigger "click"
      is_expected.to have_content "Player failed to be updated"
      is_expected.to have_css '.filtering-select[data-input-for="player_team_id"]'
    end

    it "does not prefetch pages" do
      allow_any_instance_of(RailsAdminNext::Config::Actions::Index).to receive(:controller).and_raise("index prefetched")
      visit dashboard_path
      find('.sidebar a.nav-link[href$="/player"]').hover
      sleep 0.3 # Turbo waits 100ms before prefetch
    end
  end

  describe "dom_ready events", js: true do
    it "trigger properly" do
      visit dashboard_path
      expect(evaluate_script("domReadyTriggered")).to match_array %w[plainjs/dot]
    end
  end

  context "with invalid model name" do
    it "redirects to dashboard and inform the user the model wasn't found" do
      visit "/admin/whatever"
      expect(page.driver.status_code).to eq(404)
      expect(find(".alert-danger")).to have_content("Model 'Whatever' could not be found")
    end
  end

  context "with invalid action" do
    it "redirects to balls index and inform the user the id wasn't found" do
      visit "/admin/ball/545-typo"
      expect(page.driver.status_code).to eq(404)
      expect(find(".alert-danger")).to have_content("Ball with id '545-typo' could not be found")
    end
  end
end
