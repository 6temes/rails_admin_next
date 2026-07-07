import { Controller } from "@hotwired/stimulus";

const ITEM = ".dropdown-item";

// Menu button (WAI-ARIA APG) on a native popover. The toggle is a
// <button popovertarget> and the menu carries popover="auto", so the platform
// owns the top layer, click-to-toggle, and outside-click/Escape light
// dismissal (do NOT reimplement those). The controller lives on the toggle;
// its menu is the next sibling (`.dropdown-menu`), so the menu items stay out
// of Stimulus's action-parsing scope — important because the bulk-action
// items carry their own `data-action` attribute read by interactions.js.
//
// What is left for JS:
//   - ArrowDown/ArrowUp on the closed toggle open the menu onto its
//     first/last item; opening any other way focuses the first item.
//   - ArrowUp/Down/Home/End rove focus between items; Tab closes.
//   - an item click closes the menu (clicks inside a popover don't dismiss).
//   - aria-expanded on the toggle syncs from the menu's popover toggle event,
//     and focus returns to the toggle when a light dismissal dropped it on
//     <body> (Escape restores it natively; an outside click on a
//     non-focusable target does not).
export default class extends Controller {
  #focusOnOpen = "first";
  #onToggle;
  #onMenuKeydown;
  #onMenuClick;

  connect() {
    this.element.setAttribute("aria-haspopup", "true");
    // Also resets a stale value restored from the Turbo page cache (popovers
    // are snapshotted closed, but the attribute travels as-is).
    this.element.setAttribute("aria-expanded", "false");
    this.#onToggle = this.#toggled.bind(this);
    this.#onMenuKeydown = this.#menuKeydown.bind(this);
    this.#onMenuClick = this.#menuClick.bind(this);
    this.#menu.addEventListener("toggle", this.#onToggle);
    this.#menu.addEventListener("keydown", this.#onMenuKeydown);
    this.#menu.addEventListener("click", this.#onMenuClick);
  }

  disconnect() {
    this.#menu?.removeEventListener("toggle", this.#onToggle);
    this.#menu?.removeEventListener("keydown", this.#onMenuKeydown);
    this.#menu?.removeEventListener("click", this.#onMenuClick);
  }

  // Enter, Space and click toggle natively via [popovertarget]; the arrows
  // open with an explicit landing item.
  onKeydown(event) {
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return;
    event.preventDefault();
    if (this.#menu.matches(":popover-open")) return;
    this.#focusOnOpen = event.key === "ArrowUp" ? "last" : "first";
    this.#menu.showPopover();
  }

  get #menu() {
    return this.element.nextElementSibling;
  }

  get #items() {
    return Array.from(this.#menu.querySelectorAll(ITEM));
  }

  // Popover toggle events fire for every show/hide path — the toggle button,
  // light dismissal, hidePopover(), even a <dialog> claiming the top layer.
  #toggled(event) {
    const open = event.newState === "open";
    this.element.setAttribute("aria-expanded", String(open));
    if (open) {
      const items = this.#items;
      (this.#focusOnOpen === "last" ? items.at(-1) : items[0])?.focus();
      this.#focusOnOpen = "first";
    } else if (document.activeElement === document.body) {
      this.element.focus();
    }
  }

  #menuKeydown(event) {
    const items = this.#items;
    const current = items.indexOf(document.activeElement);
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        items[(current + 1) % items.length]?.focus();
        break;
      case "ArrowUp":
        event.preventDefault();
        items[(current - 1 + items.length) % items.length]?.focus();
        break;
      case "Home":
        event.preventDefault();
        items[0]?.focus();
        break;
      case "End":
        event.preventDefault();
        items.at(-1)?.focus();
        break;
      case "Tab":
        // hidePopover() restores focus to the toggle first, so the default
        // Tab then moves on from there — the APG menu-button behavior.
        this.#menu.hidePopover();
        break;
    }
  }

  #menuClick(event) {
    if (event.target.closest(ITEM)) this.#menu.hidePopover();
  }
}
