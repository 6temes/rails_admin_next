# frozen_string_literal: true

require "spec_helper"

# Pins the cascade-layer contract of the split stylesheet (rails_admin.css -> ra.tokens,
# ra.framework, ra.skin): engine CSS lives in layers, so any UNLAYERED host rule beats it
# without specificity games. The host stylesheet is a real dummy-app asset
# (admin_host_overrides.css) injected at runtime, keeping the override out of every other
# spec.
RSpec.describe "Host CSS override", type: :request, js: true do
  # The #loading badge is rendered on every admin screen; the engine's ra.framework layer
  # gives .badge a 0.25rem (4px) border-radius.
  let(:badge_radius) { -> { page.evaluate_script("getComputedStyle(document.querySelector('#loading')).borderRadius") } }

  before { visit dashboard_path }

  it "lets an unlayered host rule beat the engine layers", :aggregate_failures do
    expect(badge_radius.call).to eq("4px")

    href = ActionController::Base.helpers.stylesheet_path("admin_host_overrides")
    page.execute_script(<<~JS)
      const link = document.createElement('link')
      link.rel = 'stylesheet'
      link.href = #{href.to_json}
      link.onload = () => document.body.setAttribute('data-host-css', 'loaded')
      document.head.appendChild(link)
    JS
    expect(page).to have_css('body[data-host-css="loaded"]')

    expect(badge_radius.call).to eq("7px")
  end
end
