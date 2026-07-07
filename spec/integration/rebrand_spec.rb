# frozen_string_literal: true

require "spec_helper"

# Pins the one-token re-brand contract of the token layer (ra.tokens): colors the engine
# derives from the public --ra-primary token — the .btn-primary background and the link
# color (--ra-link-color defaults to --ra-primary) — follow a single unlayered host
# override of that token. The override lives in the same dummy-app asset as the
# layer-order pin (admin_host_overrides.css) and is injected at runtime, keeping the
# purple brand out of every other spec.
RSpec.describe "One-token re-brand", type: :request, js: true do
  # The engine's tokens are oklch() (so computed colors serialize as oklch), while the
  # host override is a hex; normalize both through a 1x1 canvas to 8-bit "rgb(r, g, b)".
  let(:computed_rgb) do
    lambda do |selector, property|
      page.evaluate_script(<<~JS)
        (() => {
          const ctx = document.createElement('canvas').getContext('2d')
          ctx.fillStyle = getComputedStyle(document.querySelector(#{selector.to_json})).#{property}
          ctx.fillRect(0, 0, 1, 1)
          const d = ctx.getImageData(0, 0, 1, 1).data
          return `rgb(${d[0]}, ${d[1]}, ${d[2]})`
        })()
      JS
    end
  end

  # The new-record form needs no seeded rows and renders both a Save button
  # (button.btn-primary) and breadcrumb links.
  before do
    visit new_path(model_name: "league")
    # .btn transitions background-color over 0.15s, so a computed-style read taken
    # right after the token flips would return a mid-transition color.
    page.execute_script(<<~JS)
      document.head.insertAdjacentHTML('beforeend', '<style>* { transition: none !important; }</style>')
    JS
  end

  it "recolors primary buttons and links through --ra-primary", :aggregate_failures do
    expect(computed_rgb.call('button.btn-primary[name="_save"]', "backgroundColor")).to eq("rgb(13, 110, 253)")
    expect(computed_rgb.call(".breadcrumb-item a", "color")).to eq("rgb(13, 110, 253)")

    href = ActionController::Base.helpers.stylesheet_path("admin_host_overrides")
    page.execute_script(<<~JS)
      const link = document.createElement('link')
      link.rel = 'stylesheet'
      link.href = #{href.to_json}
      link.onload = () => document.body.setAttribute('data-host-css', 'loaded')
      document.head.appendChild(link)
    JS
    expect(page).to have_css('body[data-host-css="loaded"]')

    expect(computed_rgb.call('button.btn-primary[name="_save"]', "backgroundColor")).to eq("rgb(102, 51, 153)")
    expect(computed_rgb.call(".breadcrumb-item a", "color")).to eq("rgb(102, 51, 153)")
  end
end
