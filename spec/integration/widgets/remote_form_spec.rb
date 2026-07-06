# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Remote form widget", type: :request, js: true do
  subject { page }

  # Delay matching in-browser form loads so async race windows are
  # deterministic instead of depending on real network timing.
  def delay_fetch(matching, by:)
    page.execute_script(<<~JS)
      const originalFetch = window.fetch;
      window.fetch = function(...args) {
        const url = String(args[0]);
        if (url.includes(#{matching.to_json})) {
          return new Promise((resolve, reject) => {
            setTimeout(() => originalFetch.apply(window, args).then(resolve, reject), #{Integer(by)});
          });
        }
        return originalFetch.apply(window, args);
      };
    JS
  end

  # Reject matching in-browser fetches, simulating a network failure without
  # the request ever reaching the server.
  def fail_fetch(matching)
    page.execute_script(<<~JS)
      const originalFetch = window.fetch;
      window.fetch = function(...args) {
        const url = String(args[0]);
        if (url.includes(#{matching.to_json})) {
          return Promise.reject(new TypeError('Failed to fetch'));
        }
        return originalFetch.apply(window, args);
      };
    JS
  end

  # The inline-edit dialog is a native <dialog> with closedby="any": the
  # platform owns focus trapping, Escape, backdrop dismissal, ARIA semantics
  # and (with :has) the scroll lock. Escape and outside-click are exercised
  # with real CDP input — native dialogs ignore synthetic KeyboardEvents.
  describe "dialog accessibility" do
    before do
      RailsAdminNext.config Division do
        field :league
      end
    end

    def open_modal
      visit new_path(model_name: "division")
      click_link "Add a new League"
      is_expected.to have_content "New League"
    end

    it "opens as a modal dialog with focus inside" do
      open_modal
      is_expected.to have_css("#modal[open]")
      expect(
        page.evaluate_script("document.getElementById('modal').contains(document.activeElement)")
      ).to be true
    end

    it "focuses the first form field once the async form renders" do
      open_modal
      is_expected.to have_css("#league_name:focus")
    end

    it "returns focus to the trigger on close" do
      open_modal
      find("#modal .cancel-action").click
      is_expected.to have_css("a.create:focus")
    end

    it "closes on a real Escape key press" do
      open_modal
      page.driver.browser.keyboard.type(:escape)
      is_expected.not_to have_css("#modal[open]")
    end

    it "closes on a real click outside the dialog" do
      open_modal
      page.driver.browser.mouse.click(x: 5, y: 5)
      is_expected.not_to have_css("#modal[open]")
    end

    it "locks body scroll while open and releases it on close" do
      open_modal
      expect(page.evaluate_script("getComputedStyle(document.body).overflow")).to eq "hidden"
      find("#modal .cancel-action").click
      is_expected.not_to have_css("#modal[open]")
      expect(page.evaluate_script("getComputedStyle(document.body).overflow")).not_to eq "hidden"
    end

    it "announces an accessible loading state until the async form arrives" do
      visit new_path(model_name: "division")
      delay_fetch "/league/new", by: 500
      click_link "Add a new League"
      is_expected.to have_css("#modal[open]")
      # Assert the pre-render state inside the 500ms window opened above: the
      # dialog's accessible name resolves to the loading text and the still
      # empty body is flagged busy.
      state = page.evaluate_script(<<~JS)
        (() => {
          const dialog = document.getElementById('modal');
          const title = document.getElementById(dialog.getAttribute('aria-labelledby'));
          const body = dialog.querySelector('.modal-body');
          return {name: title && title.textContent.trim(), busy: body.getAttribute('aria-busy')};
        })()
      JS
      expect(state).to eq("name" => "Loading...", "busy" => "true")
      is_expected.to have_content "New League"
      expect(
        page.evaluate_script("document.querySelector('#modal .modal-body').getAttribute('aria-busy')")
      ).to be_nil
    end
  end

  # Turbo snapshots the DOM as-is, [open] attribute included; a cached
  # page restored via the back button must not resurrect an open dialog.
  describe "Turbo restore" do
    before do
      RailsAdminNext.config Division do
        field :league
      end
    end

    it "does not restore a stray open dialog from the Turbo page cache" do
      visit new_path(model_name: "division")
      click_link "Add a new League"
      is_expected.to have_content "New League"
      # The page behind a modal dialog is inert, so navigate programmatically.
      page.execute_script("Turbo.visit(#{dashboard_path.to_json})")
      expect(page).to have_current_path(dashboard_path)
      page.go_back
      expect(page).to have_current_path(new_path(model_name: "division"))
      is_expected.not_to have_css("#modal[open]")
      click_link "Add a new League"
      is_expected.to have_css("#modal[open]")
      is_expected.to have_content "New League"
    end
  end

  context "inline-edit modal integrity" do
    before do
      RailsAdminNext.config Team do
        field :division
        field :fans
      end
    end

    def expect_stale_division_load_to_be_discarded
      click_link "Add a new Fan"
      is_expected.to have_content "New Fan"
      # Not a retry-loop workaround: deliberately outlasts the 400ms delay we
      # scheduled above so the stale Division response lands in the background.
      sleep 0.5
      is_expected.to have_content "New Fan"
      is_expected.not_to have_content "New Division"
    end

    it "discards a stale form load when the dialog was dismissed with the cancel button" do
      visit new_path(model_name: "team")
      delay_fetch "/division/new", by: 400
      click_link "Add a new Division"
      find("#modal .cancel-action").click
      expect_stale_division_load_to_be_discarded
    end

    # Escape (like any closedby dismissal) bypasses the controller's
    # close action entirely, so the save-handler reset it relies on must hang
    # off the dialog's native close event.
    it "discards a stale form load when the dialog was dismissed with Escape" do
      visit new_path(model_name: "team")
      delay_fetch "/division/new", by: 400
      click_link "Add a new Division"
      is_expected.to have_css("#modal[open]")
      page.driver.browser.keyboard.type(:escape)
      is_expected.not_to have_css("#modal[open]")
      expect_stale_division_load_to_be_discarded
    end

    # The submit path shares the dialog with every association field too: a
    # submit resolving after the dialog was reopened for another field must
    # not close it out from under that field — but the record it saved
    # server-side must still land in the submitting field's own select.
    it "keeps a reopened dialog when a stale submit succeeds, still injecting into the original field" do
      visit new_path(model_name: "team")
      click_link "Add a new Fan"
      is_expected.to have_content "New Fan"
      fill_in "Name", with: "Stale fan"

      # Installed after the form load, so only the submit POST is delayed.
      delay_fetch "/fan/new", by: 800
      find("#modal .save-action").click
      page.driver.browser.keyboard.type(:escape)
      is_expected.to have_no_css("#modal[open]")
      click_link "Add a new Division"
      is_expected.to have_content "New Division"

      # Deliberately outlasts the 800ms delay so the stale submit resolves in
      # the background while the Division dialog is up.
      sleep 1

      is_expected.to have_css("#modal[open]")
      is_expected.to have_content "New Division"
      fan = Fan.where(name: "Stale fan").first
      expect(fan).not_to be nil
      expect(find("#team_fan_ids", visible: false).value).to eq [fan.id.to_s]
    end
  end

  context "with filtering select widget" do
    let(:league) { FactoryBot.create :league }
    let(:division) { FactoryBot.create :division, league: league }
    before do
      RailsAdminNext.config Division do
        field :league
      end
      RailsAdminNext.config League do
        field :name
      end
    end

    it "creates an associated record" do
      visit new_path(model_name: "division")
      click_link "Add a new League"
      is_expected.to have_content "New League"
      fill_in "Name", with: "National League"
      find("#modal .save-action").click
      expect(find("#division_custom_league_id", visible: false).value).to eq League.first.id.to_s
      expect(League.pluck(:name)).to eq ["National League"]
    end

    it "updates the associated record" do
      visit edit_path(model_name: "division", id: division.id)
      expect(find("#division_custom_league_id", visible: false).value).to eq league.id.to_s
      click_link "Edit this League"
      is_expected.to have_content "Edit League '#{league.name}'"
      fill_in "Name", with: "National League"
      find("#modal .save-action").click
      expect(find("#division_custom_league_id", visible: false).value).to eq league.id.to_s
      expect(league.reload.name).to eq "National League"
    end

    # A failed submit request (network drop) must be handled like a failed
    # form load — close the dialog — not escape as an unhandled rejection.
    it "closes the dialog when the submit request fails" do
      visit new_path(model_name: "division")
      click_link "Add a new League"
      is_expected.to have_content "New League"
      fill_in "Name", with: "National League"
      fail_fetch "/league/new"
      find("#modal .save-action").click
      is_expected.to have_no_css("#modal[open]")
      expect(League.count).to eq 0
    end

    it "creates only one record when Save is clicked twice" do
      visit new_path(model_name: "division")
      click_link "Add a new League"
      is_expected.to have_content "New League"
      fill_in "Name", with: "National League"
      # Two synchronous clicks guarantee both save() invocations happen before
      # the first fetch can resolve; separate Capybara clicks round-trip through
      # CDP and would not reliably race the in-flight submit.
      page.execute_script("const save = document.querySelector('#modal .save-action'); save.click(); save.click();")
      is_expected.not_to have_css("#modal[open]")
      expect(League.count).to eq 1
      expect(find("#division_custom_league_id", visible: false).value).to eq League.first.id.to_s
    end
  end

  context "with filtering multi-select widget" do
    let(:leagues) { FactoryBot.create_list :league, 2 }
    let!(:division) { FactoryBot.create :division, name: "National League Central", league: leagues[0] }
    before do
      RailsAdminNext.config League do
        field :divisions
      end
      RailsAdminNext.config Division do
        field :name
        field :league
      end
    end

    it "creates an associated record and adds into selection" do
      visit edit_path(model_name: "league", id: leagues[1].id)
      click_link "Add a new Division"
      is_expected.to have_content "New Division"
      fill_in "Name", with: "National League West"
      find(%(#division_custom_league_id option[value="#{leagues[0].id}"]), visible: false).select_option
      find("#modal .save-action").click
      is_expected.to have_css(".ra-multiselect-selection option", text: "National League West")
      new_division = Division.where(name: "National League West").first
      expect(new_division).not_to be nil
      expect(find("#league_division_ids", visible: false).value).to eq [new_division.id.to_s]
    end

    it "updates an unselected associated record with leaving it unselected" do
      visit edit_path(model_name: "league", id: leagues[1].id)
      find(".ra-multiselect-collection option", text: division.name).double_click
      is_expected.to have_content "Edit Division 'National League Central'"
      fill_in "Name", with: "National League East"
      find("#modal .save-action").click
      is_expected.to have_css(".ra-multiselect-collection option", text: "National League East")
      expect(find("#league_division_ids", visible: false).value).to eq []
      expect(division.reload.name).to eq "National League East"
    end

    it "updates a selected associated record" do
      visit edit_path(model_name: "league", id: leagues[0].id)
      find(".ra-multiselect-selection option", text: division.name).double_click
      is_expected.to have_content "Edit Division 'National League Central'"
      fill_in "Name", with: "National League East"
      find("#modal .save-action").click
      expect(find("#league_division_ids", visible: false).value).to eq [division.id.to_s]
      expect(division.reload.name).to eq "National League East"
    end

    context "with inline_edit set to false" do
      before do
        RailsAdminNext.config League do
          field :divisions do
            inline_edit false
          end
        end
      end

      it "does not open the modal with double click" do
        visit edit_path(model_name: "league", id: leagues[1].id)
        find(".ra-multiselect-collection option", text: division.name).double_click
        is_expected.not_to have_content "Edit Division 'National League Central'"
      end
    end
  end

  context "with file upload" do
    before do
      RailsAdminNext.config NestedFieldTest do
        field :field_test
      end
      RailsAdminNext.config FieldTest do
        field :active_storage_asset
      end
    end

    it "submits successfully" do
      visit new_path(model_name: "nested_field_test")
      click_link "Add a new Field test"
      is_expected.to have_content "New Field test"
      attach_file "Active storage asset", file_path("test.jpg")
      find("#modal .save-action").click
      is_expected.to have_css("option", text: /FieldTest #/, visible: false)
      expect(FieldTest.first.active_storage_asset.blob.byte_size).to eq 1575
    end
  end

  context "with validation errors" do
    before do
      RailsAdminNext.config Team do
        field :players
        field :fans
      end
      RailsAdminNext.config Player do
        field :name
        field :number
        field :team
      end
    end

    context "on create" do
      it "keeps the dialog open, shows the errors and focuses an invalid field" do
        visit new_path(model_name: "team")
        click_link "Add a new Player"
        is_expected.to have_content "New Player"
        find("#player_name").set("on steroids")
        find("#modal .save-action").click
        is_expected.to have_content "Player is cheating"
        is_expected.to have_css("#modal[open]")
        is_expected.to have_css ".text-danger", text: "is not a number"
        expect(page.evaluate_script("document.activeElement.getAttribute('aria-invalid')")).to eq "true"
      end
    end

    context "on update" do
      let!(:player) { FactoryBot.create :player, name: "Cheater" }

      it "keeps the dialog open, shows the errors and focuses an invalid field" do
        visit new_path(model_name: "team")
        find("option", text: "Cheater").double_click
        is_expected.to have_content "Edit Player 'Cheater'"
        find("#player_name").set("Cheater on steroids")
        find("#player_number").set("")
        find("#modal .save-action").click
        is_expected.to have_content "Player is cheating"
        is_expected.to have_css("#modal[open]")
        is_expected.to have_css ".text-danger", text: "is not a number"
        expect(page.evaluate_script("document.activeElement.getAttribute('aria-invalid')")).to eq "true"
      end
    end

    # The submit path has the same stale-response race as the load path: a 422
    # landing after the dialog was dismissed must not repopulate the reset body
    # (the stale errored form would resurface on the next open).
    it "discards a late 422 response when the dialog was dismissed mid-submit" do
      visit new_path(model_name: "team")
      click_link "Add a new Player"
      is_expected.to have_content "New Player"
      find("#player_name").set("on steroids")

      delay_fetch "/player/new", by: 400
      find("#modal .save-action").click
      page.driver.browser.keyboard.type(:escape)
      is_expected.to have_no_css("#modal[open]")

      # Deliberately outlasts the 400ms delay so the 422 lands in the background.
      sleep 0.6

      # The reopen must come up in the LOADING state (the fresh fetch is also
      # delayed 400ms): if the late 422 had repopulated the body, the stale
      # errored form would be visible right now, before the fresh form lands.
      click_link "Add a new Player"
      is_expected.to have_css("#modal[open]")
      expect(page).to have_no_content("Player is cheating", wait: 0)
      is_expected.to have_css('#modal .modal-body[aria-busy="true"]', wait: 0)

      is_expected.to have_content "New Player"
      expect(find("#player_name").value).to eq ""
    end

    # Same race, dialog reopened instead of left closed: a 422 landing after
    # the dialog was grabbed for another field must not clobber that field's
    # form with the stale errored one.
    it "discards a late 422 response when the dialog was reopened for another field mid-submit" do
      visit new_path(model_name: "team")
      click_link "Add a new Player"
      is_expected.to have_content "New Player"
      find("#player_name").set("on steroids")

      # Installed after the form load, so only the submit POST is delayed.
      delay_fetch "/player/new", by: 800
      find("#modal .save-action").click
      page.driver.browser.keyboard.type(:escape)
      is_expected.to have_no_css("#modal[open]")
      click_link "Add a new Fan"
      is_expected.to have_content "New Fan"

      # Deliberately outlasts the 800ms delay so the 422 lands while the Fan
      # dialog is up.
      sleep 1

      is_expected.to have_css("#modal[open]")
      is_expected.to have_content "New Fan"
      expect(page).to have_no_content("Player is cheating", wait: 0)
    end
  end
end
