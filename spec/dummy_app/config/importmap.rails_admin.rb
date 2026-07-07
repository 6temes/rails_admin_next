# frozen_string_literal: true

# Host-side overrides, appended to the engine's importmap by RailsAdminNext::Engine ("RailsAdminNext assets").
# Point the `rails_admin` entrypoint at this app's own module (app/javascript/rails_admin.js) so it can
# start ActiveStorage/ActionText and install the dom_ready test hooks on top of the engine base. All
# library pins (@rails/activestorage, trix, …) are inherited from the engine importmap, so they are not
# repeated here.
pin "rails_admin", to: "rails_admin.js", preload: true
