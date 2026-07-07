import { Controller } from "@hotwired/stimulus";

// Responsive navbar toggler (WAI-ARIA disclosure): the hamburger toggles
// `aria-expanded` and the region's Bootstrap `.collapse`/`.show` classes
// (`.collapse:not(.show)` is hidden; `.navbar-expand-md` forces the region
// visible above the breakpoint). The sidebar groups use native <details>, but a
// <details> navbar can't be force-expanded at the md breakpoint, so the navbar
// stays class-driven.
export default class extends Controller {
  static targets = ["trigger", "region"];

  toggle() {
    const expanded = this.regionTarget.classList.toggle("show");
    this.triggerTarget.setAttribute("aria-expanded", String(expanded));
  }
}
