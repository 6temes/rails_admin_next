import I18n from "rails_admin/i18n";

// Fires the `rails_admin.dom_ready` event exactly once per navigation:
// DOMContentLoaded covers the cold page load, turbo:render covers subsequent
// Turbo Drive visits — the two are mutually exclusive.
function triggerDomReady() {
  const admin = document.getElementById("admin-js");
  I18n.init(document.documentElement.lang, admin && admin.dataset.i18nOptions);
  document.dispatchEvent(new CustomEvent("rails_admin.dom_ready"));
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", triggerDomReady);
} else {
  // Already loaded: defer to the next tick so the rest of the module graph (and
  // any host-registered rails_admin.dom_ready listeners imported after us) has
  // finished evaluating before the event fires.
  setTimeout(triggerDomReady, 0);
}
document.addEventListener("turbo:render", triggerDomReady);
