# frozen_string_literal: true

# Host-app importmap for the dummy app's own (non-admin) pages. The admin UI loads its
# JavaScript from the engine importmap (see config/importmap.rails_admin.rb); nothing here
# is required by RailsAdminNext. Turbo is self-hosted off the turbo-rails gem (turbo.min.js,
# on the Propshaft load path) — same as the engine — so the host pages need no jspm either.
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
