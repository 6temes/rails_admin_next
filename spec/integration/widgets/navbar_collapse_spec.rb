# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Navbar collapse widget", type: :request, js: true do
  subject { page }

  # The navbar toggler only shows below the md breakpoint, so drive this at a
  # mobile width and restore the default viewport for the rest of the suite.
  before { page.current_window.resize_to(420, 760) }
  after { page.current_window.resize_to(1024, 768) }

  it "keeps the toggler's label for screen readers only" do
    visit dashboard_path

    label = find(".navbar-toggler", text: "Toggle navigation")
    width = page.evaluate_script("arguments[0].querySelector('span:not(.navbar-toggler-icon)').getBoundingClientRect().width", label)
    expect(width).to be <= 1
  end

  it "toggles the secondary navigation and tracks aria-expanded" do
    visit dashboard_path

    toggler = find(".navbar-toggler")
    is_expected.to have_selector('.navbar-toggler[aria-expanded="false"]')
    is_expected.to have_no_selector("#secondary-navigation.show")

    toggler.click
    is_expected.to have_selector('.navbar-toggler[aria-expanded="true"]')
    is_expected.to have_selector("#secondary-navigation.show")

    toggler.click
    is_expected.to have_selector('.navbar-toggler[aria-expanded="false"]')
    is_expected.to have_no_selector("#secondary-navigation.show")
  end
end
