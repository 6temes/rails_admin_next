import "@hotwired/turbo-rails";

// RailsAdminNext's own Stimulus application + controllers.
import "rails_admin/application";
import "rails_admin/controllers";

// Vanilla, jQuery-free document-level page interactions.
import "rails_admin/interactions";

// Owns rails_admin.dom_ready. Imported last so every listener registered above
// is in place before the first dispatch fires.
import "rails_admin/dom-ready";
