import { Controller } from "@hotwired/stimulus";

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

// Dismissible flash alert. Replaces Bootstrap's data-bs-dismiss="alert".
// Removing an alert with the keyboard would otherwise drop focus to <body>, so
// on dismiss focus returns to the nearest focusable element preceding the alert
// (falling back to the first focusable element on the page).
export default class extends Controller {
  dismiss() {
    const target = this.#focusReturnTarget();
    this.element.remove();
    target?.focus();
  }

  #focusReturnTarget() {
    const focusable = Array.from(document.querySelectorAll(FOCUSABLE)).filter(
      (el) => !this.element.contains(el) && el.offsetParent !== null
    );
    const preceding = focusable.filter(
      (el) =>
        this.element.compareDocumentPosition(el) &
        Node.DOCUMENT_POSITION_PRECEDING
    );
    return preceding.at(-1) || focusable[0] || null;
  }
}
