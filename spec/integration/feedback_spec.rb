# frozen_string_literal: true

require "spec_helper"

# The shared feedback Stimulus controller drives submit affordances off the Turbo submit
# lifecycle — symmetric disable/enable, no fixed timeouts.
RSpec.describe "Form feedback (Turbo submit lifecycle)", type: :request do
  subject { page }

  before do
    @player = FactoryBot.create :player
    visit edit_path(model_name: "player", id: @player.id)
  end

  it "wires the feedback controller onto the admin form" do
    is_expected.to have_css 'form.main[data-controller~="feedback"]'
  end

  it "disables the submit control and marks the form busy on submit-start, reversing both on submit-end", js: true do
    # Drive the lifecycle directly so the assertion is about the controller's
    # contract, not network timing (the events Turbo would fire on a real submit).
    page.execute_script(<<~JS)
      document.querySelector('form.main')
        .dispatchEvent(new CustomEvent('turbo:submit-start', { bubbles: true }));
    JS
    is_expected.to have_css 'form.main[aria-busy="true"]'
    is_expected.to have_button "Save", disabled: true

    page.execute_script(<<~JS)
      document.querySelector('form.main')
        .dispatchEvent(new CustomEvent('turbo:submit-end', { bubbles: true }));
    JS
    is_expected.to have_no_css 'form.main[aria-busy="true"]'
    is_expected.to have_button "Save", disabled: false
  end

  it "leaves the form usable after a 422 validation failure (no stuck-disabled state)", js: true do
    fill_in "player[name]", with: "on steroids"
    find_button("Save").trigger "click"

    is_expected.to have_content "Player failed to be updated"
    is_expected.to have_no_css 'form.main[aria-busy="true"]'
    is_expected.to have_button "Save", disabled: false
  end
end
