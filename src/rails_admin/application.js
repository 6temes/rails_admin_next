import { Application } from "@hotwired/stimulus";

// RailsAdminNext runs its OWN Stimulus application, separate from any Stimulus app the
// host may run for its own UI. Controllers are registered against this instance
// (see ./controllers/index.js) so the engine never reaches into — or depends on —
// the host's controllers/ directory.
const application = Application.start();
application.warnings = false;
application.debug = false;

// Expose for debugging and host extension under the engine namespace.
window.RailsAdminNext = window.RailsAdminNext || {};
window.RailsAdminNext.application = application;

export { application };
