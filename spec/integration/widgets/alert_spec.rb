# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Alert dismiss widget", type: :request, js: true do
  subject { page }

  # Visiting a missing record redirects to the list with a flash error, which is
  # the dismissible alert under test.
  before { visit edit_path(model_name: "league", id: 0) }

  it "shows the dismissible flash alert" do
    is_expected.to have_selector(".alert.alert-dismissible")
    is_expected.to have_content("could not be found")
  end

  it "removes the alert on dismiss and returns focus to a focusable element" do
    find(".alert.alert-dismissible .btn-close").click

    is_expected.to have_no_selector(".alert.alert-dismissible")
    # Focus is returned to a real element, never dropped to <body>.
    expect(page.evaluate_script("document.activeElement === document.body")).to be false
  end
end
