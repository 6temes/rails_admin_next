import { Controller } from "@hotwired/stimulus";

const BUSY_CLASS = "rails_admin-submitting";

// Shared UX-feedback for Turbo-driven forms. Wired onto every admin form by
// RailsAdminNext::MainHelper#rails_admin_form_for as:
//
//   data-controller="feedback"
//   data-action="turbo:submit-start->feedback#start turbo:submit-end->feedback#end"
//
// `start` disables the form's submit controls and marks the form busy; `end`
// reverses both symmetrically. Turbo fires `turbo:submit-end` on success AND on a
// 422 validation failure, so the form never gets stuck disabled. State is driven
// entirely by the Turbo submit lifecycle — there are no fixed timeouts.
//
// On connect it also flags every errored field `aria-invalid="true"` and moves
// focus to the first one, so a 422 re-render (which Turbo renders in place,
// re-running connect) lands the cursor on the field that needs fixing —
// including fields inside nested subforms.
export default class extends Controller {
  connect() {
    // A back/forward-cache restore can replay a snapshot captured mid-submit;
    // start every connection from a clean, non-busy state.
    this.#reset();
    this.#flagInvalidFields();
  }

  start() {
    this.element.setAttribute("aria-busy", "true");
    this.element.classList.add(BUSY_CLASS);
    this.#submitControls.forEach((control) => {
      control.disabled = true;
      this.#disabledControls.add(control);
    });
  }

  end() {
    this.#reset();
  }

  // RailsAdminNext marks an errored field's wrapper `.control-group.error`; expose
  // that on the inputs themselves as `aria-invalid` and focus the first. Focus
  // is only taken from a freshly rendered page (activeElement is the body), so
  // a user already typing somewhere is never interrupted.
  #flagInvalidFields() {
    const invalid = this.element.querySelectorAll(
      ".control-group.error input:not([type='hidden']), .control-group.error select, .control-group.error textarea"
    );
    invalid.forEach((field) => field.setAttribute("aria-invalid", "true"));

    const focusable = document.activeElement;
    if (invalid[0] && (!focusable || focusable === document.body)) {
      invalid[0].focus();
    }
  }

  #reset() {
    this.element.removeAttribute("aria-busy");
    this.element.classList.remove(BUSY_CLASS);
    this.#disabledControls.forEach((control) => {
      control.disabled = false;
    });
    this.#disabledControls.clear();
  }

  get #submitControls() {
    return this.element.querySelectorAll(
      'input[type="submit"], button[type="submit"], button:not([type])'
    );
  }

  #disabledControls = new Set();
}
