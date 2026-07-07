# frozen_string_literal: true

require "spec_helper"

# The menus are native popovers — [popover="auto"] menus toggled by
# [popovertarget] buttons — so the platform owns the top layer,
# click-to-toggle, outside-click and Escape light dismissal; DropdownController
# keeps the APG menu-button keyboard pattern (arrow roving, Tab-close, close on
# item click) and the aria-expanded/focus sync. Escape/Tab/arrows and outside
# clicks are exercised with real CDP input — the platform's light-dismiss
# machinery ignores synthetic KeyboardEvents.
RSpec.describe "Dropdown widget", type: :request, js: true do
  subject { page }

  describe "filter menu" do
    before { visit index_path(model_name: "field_test") }

    let(:toggle) { find("button#filters_toggle") }

    it "opens on a toggle click and closes on a second click, syncing aria-expanded" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")
      is_expected.to have_css("#filters_toggle[aria-expanded='true']")

      # Anchored to ITS OWN toggle (end-aligned — the menu carries
      # .dropdown-menu-end): with a shared anchor-name the menu resolves to
      # the last same-named anchor on the page and attaches to the bulk
      # toggle instead (pinned here).
      edges = page.evaluate_script(<<~JS)
        (() => {
          const menu = document.getElementById('filters').getBoundingClientRect();
          const toggle = document.getElementById('filters_toggle').getBoundingClientRect();
          return {menuRight: menu.right, toggleRight: toggle.right, menuTop: menu.top, toggleBottom: toggle.bottom};
        })()
      JS
      expect(edges["menuRight"]).to be_within(1).of(edges["toggleRight"])
      expect(edges["menuTop"]).to be_within(1).of(edges["toggleBottom"])

      toggle.click
      is_expected.to have_no_css("#filters:popover-open")
      is_expected.to have_css("#filters_toggle[aria-expanded='false']")
    end

    it "focuses the first menu item on open" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")
      # The focus move rides the (queued) popover toggle event, so wait on it.
      is_expected.to have_css("#filters .dropdown-item:focus")
    end

    # Both light-dismiss paths close the menu, sync aria-expanded on the
    # toggle and land focus back on it.
    it "closes on a real Escape key press, returning focus to the toggle" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")

      page.driver.browser.keyboard.type(:escape)

      is_expected.to have_no_css("#filters:popover-open")
      is_expected.to have_css("#filters_toggle[aria-expanded='false']")
      expect(page.evaluate_script("document.activeElement.id")).to eq "filters_toggle"
    end

    it "closes on a real outside click, returning focus to the toggle" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")

      find("h1").click

      is_expected.to have_no_css("#filters:popover-open")
      is_expected.to have_css("#filters_toggle[aria-expanded='false']")
      expect(page.evaluate_script("document.activeElement.id")).to eq "filters_toggle"
    end

    it "opens onto the first item with ArrowDown on the toggle and onto the last with ArrowUp" do
      labels = page.evaluate_script(
        "Array.from(document.querySelectorAll('#filters .dropdown-item'), (item) => item.textContent.trim())"
      )

      # Focus the toggle without Element#send_keys: Cuprite focuses a node by
      # clicking it, and a click on a [popovertarget] button already toggles
      # the popover before the key goes out.
      page.execute_script("document.getElementById('filters_toggle').focus()")
      page.driver.browser.keyboard.type(:down)
      is_expected.to have_css("#filters:popover-open")
      is_expected.to have_css("#filters .dropdown-item:focus", exact_text: labels.first)

      page.driver.browser.keyboard.type(:escape)
      is_expected.to have_no_css("#filters:popover-open")

      # Escape returned focus to the toggle, so the next key lands there.
      page.driver.browser.keyboard.type(:up)
      is_expected.to have_css("#filters:popover-open")
      is_expected.to have_css("#filters .dropdown-item:focus", exact_text: labels.last)
    end

    it "roves focus through the items with real arrow key presses" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")
      is_expected.to have_css("#filters .dropdown-item:focus")
      first = page.evaluate_script("document.activeElement.textContent.trim()")

      page.driver.browser.keyboard.type(:down)
      expect(page.evaluate_script("document.activeElement.matches('.dropdown-item')")).to be true
      expect(page.evaluate_script("document.activeElement.textContent.trim()")).not_to eq first

      page.driver.browser.keyboard.type(:up)
      expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq first
    end

    it "closes on a real Tab key press without trapping focus" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")

      page.driver.browser.keyboard.type(:tab)

      is_expected.to have_no_css("#filters:popover-open")
      expect(page.evaluate_script("document.activeElement.closest('#filters')")).to be_nil
    end

    it "adds a filter and closes when a menu item is chosen" do
      toggle.click
      is_expected.to have_css("#filters:popover-open")

      find("#filters .dropdown-item", match: :first).click

      is_expected.to have_no_css("#filters:popover-open")
      is_expected.to have_css("#filters_box .filter")
    end
  end

  describe "bulk menu" do
    let!(:selected) { FactoryBot.create :player, name: "Bulk me" }
    let!(:unselected) { FactoryBot.create :player, name: "Spare me" }

    it "fires the bulk action for the checked rows from a menu item" do
      visit index_path(model_name: "player")
      find("input[name='bulk_ids[]'][value='#{selected.id}']").check

      find("button#bulk_menu_toggle").click
      is_expected.to have_css("#bulk_menu:popover-open")

      # End-aligned via anchor CSS: an inline style="left:auto; right:0;" would violate the
      # CSP inline-style restriction, so positioning goes through CSS anchor positioning instead.
      edges = page.evaluate_script(<<~JS)
        (() => {
          const menu = document.getElementById('bulk_menu').getBoundingClientRect();
          const toggle = document.getElementById('bulk_menu_toggle').getBoundingClientRect();
          return {menu: menu.right, toggle: toggle.right};
        })()
      JS
      expect(edges["menu"]).to be_within(1).of(edges["toggle"])

      find("#bulk_menu .bulk-link", text: "Delete selected Players").click

      is_expected.to have_content "The following objects will be deleted"
      is_expected.to have_content "Bulk me"
      is_expected.to have_no_content "Spare me"
    end
  end

  describe "viewport-edge positioning" do
    before do
      # Two list fields keep the menu short enough to fit in the space above
      # the toggle once the window is shrunk below it.
      RailsAdminNext.config FieldTest do
        list do
          field :string_field
          field :integer_field
        end
      end
    end

    it "flips the menu above the toggle when there is no room below" do
      original = page.current_window.size
      page.current_window.resize_to(original[0], 240)
      visit index_path(model_name: "field_test")

      find("button#filters_toggle").click
      is_expected.to have_css("#filters:popover-open")

      rects = page.evaluate_script(<<~JS)
        (() => {
          const menu = document.getElementById('filters').getBoundingClientRect();
          const toggle = document.getElementById('filters_toggle').getBoundingClientRect();
          return {menuBottom: menu.bottom, toggleTop: toggle.top};
        })()
      JS
      expect(rects["menuBottom"]).to be <= rects["toggleTop"]
    ensure
      page.current_window.resize_to(*original) if original
    end
  end

  describe "viewport overflow clamping" do
    # Field test's full filter menu (~30 items) fits neither below nor above
    # the toggle at this height, so flip-block fails and the last-resort
    # @position-try pins the menu to the viewport bottom and scrolls it.
    it "pins an over-tall menu to the viewport and scrolls it instead of clipping" do
      original = page.current_window.size
      page.current_window.resize_to(original[0], 500)
      visit index_path(model_name: "field_test")

      find("button#filters_toggle").click
      is_expected.to have_css("#filters:popover-open")

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const menu = document.getElementById('filters');
          const rect = menu.getBoundingClientRect();
          const toggle = document.getElementById('filters_toggle').getBoundingClientRect();
          return {menuTop: rect.top, menuBottom: rect.bottom, toggleBottom: toggle.bottom,
                  viewport: window.innerHeight, scrollable: menu.scrollHeight > menu.clientHeight};
        })()
      JS
      expect(metrics["menuTop"]).to be_within(1).of(metrics["toggleBottom"])
      expect(metrics["menuBottom"]).to be <= metrics["viewport"]
      expect(metrics["scrollable"]).to be true
    ensure
      page.current_window.resize_to(*original) if original
    end
  end

  describe "top-layer interaction with the inline-edit dialog" do
    # No screen hosts both a dropdown toggle and a dialog trigger (the menus
    # live on list screens, the dialog's create/edit triggers on form screens),
    # but the layout-level <dialog id="modal"> is present everywhere — open it
    # exactly the way ModalController#open does (showModal()) and let the
    # platform tear the popover down.
    it "tears the popover down when the dialog claims the top layer" do
      visit index_path(model_name: "field_test")
      find("button#filters_toggle").click
      is_expected.to have_css("#filters:popover-open")

      page.execute_script("document.getElementById('modal').showModal()")

      is_expected.to have_css("#modal[open]")
      is_expected.to have_no_css("#filters:popover-open")
      is_expected.to have_css("#filters_toggle[aria-expanded='false']")
    end
  end
end
