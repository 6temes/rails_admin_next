# frozen_string_literal: true

# Engine-owned importmap, drawn by lib/rails_admin_next/engine.rb and distinct from the host's
# config/importmap.rb. Rendered inline (CSP-nonce threaded) on admin pages by
# app/views/layouts/rails_admin_next/_head.html.erb.

# rails_admin's own browser-native ESM modules — served and fingerprinted by Propshaft from src/.
# pin_all_from covers the controllers/ manifest and every controller too (rails_admin/controllers/*).
pin "rails_admin", to: "rails_admin/base.js", preload: true
pin_all_from File.expand_path("../src/rails_admin", __dir__), under: "rails_admin"

# Self-hosted survivors. Stimulus (a genuinely new dependency) and Turbo ship single, pre-bundled
# browser-native ESM files from their gems, served and fingerprinted by Propshaft off each gem's
# auto-registered asset path — no jspm, no build step.
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true

# The @rails/* and trix modules are self-hosted too: each is a single pre-bundled browser-native ESM
# file shipped inside its Rails gem (actioncable/activestorage/actiontext) or action_text-trix, served
# and fingerprinted by Propshaft off the gem's auto-registered asset path — zero external network, JS
# versioned in lockstep with the gems (no jspm Dependabot blind spot). actioncable's asset path is
# registered by the `require 'action_cable/engine'` in engine.rb (the @rails/activestorage/actiontext
# and trix paths come from the host's ActiveStorage/ActionText, which load action_text-trix). There is
# no jQuery, jQuery-UI, or @rails/ujs pin: destructive actions use Turbo's data-turbo-method/
# data-turbo-confirm attributes, and date/time fields use native HTML5 inputs (no JS library).
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "trix", to: "trix.js"
