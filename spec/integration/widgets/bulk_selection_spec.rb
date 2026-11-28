# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Bulk selection under infinite scroll", type: :request do
  subject { page }

  before { RailsAdminNext.config.default_items_per_page = 20 }

  it "renders the bulk links and a disabled all-matching fieldset without JavaScript", :aggregate_failures do
    FactoryBot.create_list(:player, 25)
    visit index_path(model_name: "player", query: "", sort: "name", sort_reverse: "true", f: {name: {"1" => {o: "like", v: "a"}}})

    is_expected.to have_css("#bulk_form .selection-bar #bulk_menu a.bulk-link[data-bulk-action='bulk_delete']", text: "Delete selected Players")
    is_expected.to have_css("#bulk_form .selection-bar #bulk_menu a.bulk-link[data-bulk-action='export']", text: "Export selected Players")
    is_expected.to have_no_css("#bulk_form a.bulk-link[data-action]")
    fieldset = find("#bulk_form fieldset.all-matching[disabled]", visible: false)
    fields = fieldset.all("input[type=hidden]", visible: false).to_h { [it[:name], it[:value]] }
    expect(fields).to eq("all_matching" => "true", "query" => "", "sort" => "name", "sort_reverse" => "true", "f[name][1][o]" => "like", "f[name][1][v]" => "a")
  end

  describe "in the browser", js: true do
    after { page.current_window.resize_to(1024, 768) }

    # At this height the second batch's frame stays beyond the one-viewport
    # look-ahead, so exactly one batch is loaded until the page scrolls.
    def short_window = page.current_window.resize_to(1024, 400)

    def header = find("#bulk_form input.toggle")

    def bar = find("#bulk_form .selection-bar")

    def checked_rows = all("tbody#list_rows input[name='bulk_ids[]']:checked")

    def scroll_to_bottom = page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

    def scroll_until(selector, **)
      page.document.synchronize(10) do
        scroll_to_bottom
        raise Capybara::ExpectationNotMet, "never found #{selector}" unless page.has_css?(selector, wait: 0, **)
      end
    end

    def all_matching_input = find("#bulk_form fieldset.all-matching input[name='all_matching']", visible: false)

    def open_bulk_menu
      find("button#bulk_menu_toggle").click
      is_expected.to have_css("#bulk_menu:popover-open")
    end

    def bulk_requests
      @bulk_requests ||= []
    end

    def capture_bulk_requests
      @subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
        bulk_requests << payload[:params] if payload[:action] == "bulk_action"
      end
    end

    after { ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber }

    context "with 300 matching players" do
      before { FactoryBot.create_list(:player, 300) }

      def visit_one_batch
        short_window
        visit index_path(model_name: "player")
        is_expected.to have_css("tbody#list_rows tr", count: 20)
      end

      # At the default window size the look-ahead loads the second batch on its own.
      def visit_two_batches
        visit index_path(model_name: "player")
        is_expected.to have_css("tbody#list_rows tr", minimum: 40)
      end

      it "hides the bar while no row is ticked and keeps the bulk menu out of the contextual tabs", :aggregate_failures do
        visit_one_batch
        is_expected.to have_no_css(".selection-bar", visible: :visible)
        is_expected.to have_no_css(".nav-tabs #bulk_menu_toggle", visible: :all)
      end

      it "shows the count and the menu toggle, without the offer, when one row is ticked" do
        visit_one_batch
        first("tbody#list_rows input[name='bulk_ids[]']").check

        expect(bar).to have_css(".selection-count", text: "1 selected")
        expect(bar).to have_button("Selected items")
        expect(bar).to have_no_button(/Select all/)
      end

      it "ticks every loaded row from the header and offers every matching record", :aggregate_failures do
        visit_one_batch
        header.check

        expect(checked_rows.size).to eq 20
        expect(bar).to have_css(".selection-count", text: "20 selected")
        expect(bar).to have_button("Select all 300 matching players")
      end

      it "selects every matching record, ticks the rows that load next, and drops back to an explicit selection on an untick", :aggregate_failures do
        visit_two_batches
        header.check
        bar.click_button("Select all 300 matching players")

        expect(bar).to have_css(".selection-all-matching", text: "All 300 matching players are selected")
        expect(bar).to have_no_css(".selection-count", visible: :visible)
        expect(all_matching_input).not_to be_disabled
        scroll_until("tbody#list_rows tr", minimum: 60)
        expect(all("tbody#list_rows input[name='bulk_ids[]']").map(&:checked?)).to all(be true)

        first("tbody#list_rows input[name='bulk_ids[]']").uncheck
        ticked = checked_rows.size
        expect(bar).to have_css(".selection-count", text: "#{ticked} selected")
        expect(bar).to have_no_css(".selection-all-matching", visible: :visible)
        expect(all_matching_input).to be_disabled
      end

      it "clears the whole selection and the all-matching state when the header is unticked", :aggregate_failures do
        visit_one_batch
        header.check
        bar.click_button("Select all 300 matching players")
        expect(all_matching_input).not_to be_disabled

        header.uncheck
        expect(checked_rows).to be_empty
        is_expected.to have_no_css(".selection-bar", visible: :visible)
        expect(all_matching_input).to be_disabled
      end

      it "leaves rows loaded after a header selection unticked and withdraws the offer", :aggregate_failures do
        visit_one_batch
        header.check
        expect(bar).to have_button("Select all 300 matching players")

        scroll_until("tbody#list_rows tr", minimum: 40)
        expect(checked_rows.size).to eq 20
        expect(bar).to have_css(".selection-count", text: "20 selected")
        expect(bar).to have_no_button(/Select all/)
        expect(header).not_to be_checked
        expect(page.evaluate_script("document.querySelector('#bulk_form input.toggle').indeterminate")).to be true
      end

      it "keeps the bar and the menu toggle in view below the navbar when scrolled far down", :aggregate_failures do
        visit_one_batch
        first("tbody#list_rows input[name='bulk_ids[]']").check
        scroll_until("tbody#list_rows tr", minimum: 60)

        edges = page.evaluate_script(<<~JS)
          (() => {
            const navbar = document.querySelector(".navbar").getBoundingClientRect();
            const bar = document.querySelector(".selection-bar").getBoundingClientRect();
            const toggle = document.getElementById("bulk_menu_toggle").getBoundingClientRect();
            return {navbar: navbar.bottom, bar: bar.top, toggleTop: toggle.top, toggleBottom: toggle.bottom, viewport: window.innerHeight, scrollY: window.scrollY};
          })()
        JS
        expect(edges["scrollY"]).to be > 1000
        expect(edges["bar"]).to be_within(1).of(edges["navbar"])
        expect(edges["toggleTop"]).to be >= edges["navbar"]
        expect(edges["toggleBottom"]).to be <= edges["viewport"]
      end

      it "posts the flag without the ticked ids when acting on every matching record", :aggregate_failures do
        capture_bulk_requests
        visit_two_batches
        header.check
        bar.click_button("Select all 300 matching players")

        open_bulk_menu
        find("#bulk_menu .bulk-link", text: "Export selected Players").click
        is_expected.to have_css("form.main[action*='/export']")

        expect(bulk_requests.size).to eq 1
        expect(bulk_requests.first).to include("all_matching" => "true", "bulk_action" => "export")
        expect(bulk_requests.first).not_to have_key("bulk_ids")
      end

      it "keeps the ticks and the all-matching state after Back from a row's page", :aggregate_failures do
        visit_one_batch
        header.check
        bar.click_button("Select all 300 matching players")
        expect(all_matching_input).not_to be_disabled

        find("tbody#list_rows tr:first-child td.links a[href$='/player/#{Player.order(id: :desc).first.id}']").click
        is_expected.to have_no_css("tbody#list_rows")
        page.go_back

        is_expected.to have_css("tbody#list_rows tr", minimum: 20)
        expect(all("tbody#list_rows input[name='bulk_ids[]']").map(&:checked?)).to all(be true)
        expect(bar).to have_css(".selection-all-matching", text: "All 300 matching players are selected")
        expect(all_matching_input).not_to be_disabled
      end
    end

    context "with a host bulk action that has not opted in" do
      before do
        RailsAdminNext::Config::Actions.all
        RailsAdminNext::Config::Actions.collection :tag_players do
          bulkable true
          http_methods %i[post]
          controller { proc { head :ok } }
        end
        Rails.application.reload_routes!
        I18n.backend.store_translations(:en, admin: {actions: {tag_players: {bulk_link: "Tag selected %{model_label_plural}"}}})
        FactoryBot.create_list(:player, 25)
        short_window
        visit index_path(model_name: "player")
        is_expected.to have_css("tbody#list_rows tr", count: 20)
      end

      it "offers it for an explicit selection only", :aggregate_failures do
        header.check
        open_bulk_menu
        expect(find("#bulk_menu")).to have_link("Tag selected Players")
        find("button#bulk_menu_toggle").click
        is_expected.to have_no_css("#bulk_menu:popover-open")

        bar.click_button("Select all 25 matching players")
        open_bulk_menu
        expect(find("#bulk_menu")).to have_link("Delete selected Players")
        expect(find("#bulk_menu")).to have_no_link("Tag selected Players")
        find("button#bulk_menu_toggle").click
        is_expected.to have_no_css("#bulk_menu:popover-open")

        first("tbody#list_rows input[name='bulk_ids[]']").uncheck
        open_bulk_menu
        expect(find("#bulk_menu")).to have_link("Tag selected Players")
      end
    end

    it "offers every matching record without a number on a limited_pagination list" do
      RailsAdminNext.config(Player) { list { limited_pagination true } }
      FactoryBot.create_list(:player, 25)
      short_window
      visit index_path(model_name: "player")
      is_expected.to have_css("tbody#list_rows tr", count: 20)

      header.check
      expect(bar).to have_button(exact_text: "Select all matching players")
      bar.click_button("Select all matching players")
      expect(bar).to have_css(".selection-all-matching", exact_text: "All matching players are selected")
    end

    it "shows the count and no offer on a list that fits in one batch" do
      FactoryBot.create_list(:player, 3)
      visit index_path(model_name: "player")

      header.check
      expect(bar).to have_css(".selection-count", text: "3 selected")
      expect(bar).to have_no_button(/Select all/)
    end

    it "reaches the action's page from the bulk menu with no JS error" do
      players = FactoryBot.create_list(:player, 3)
      visit index_path(model_name: "player")

      find("input[name='bulk_ids[]'][value='#{players.first.id}']").check
      open_bulk_menu
      find("#bulk_menu .bulk-link", text: "Delete selected Players").click

      is_expected.to have_content "The following objects will be deleted"
      is_expected.to have_content players.first.name
    end
  end
end
