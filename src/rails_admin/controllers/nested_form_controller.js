import { Controller } from "@hotwired/stimulus";

// Drives RailsAdminNext's nested association forms. The server renders subforms
// with native Rails
// `fields_for` + `accepts_nested_attributes_for`; this controller owns the
// add/remove/mark-for-destroy lifecycle:
//
//   - add: clones a blank subform from the <template>. For a has_many
//     association the template carries a child-index placeholder
//     (e.g. "new_nested_field_tests") which is swapped for a unique value so
//     each new row submits under its own index; has_one/belongs_to subforms
//     have no placeholder. Focus then moves to the first visible field.
//   - remove on an unsaved subform deletes it from the DOM.
//   - remove on a persisted subform sets its `_destroy` hidden field and dims
//     it ("will be removed on save"); the record is destroyed only on submit.
//     Required inputs in a doomed subform are relaxed so they can't block
//     native form validation. A second click un-marks it.
//   - singular (has_one/belongs_to) associations hold at most one subform; the
//     Add control's visibility is not mirrored here — :has() CSS (skin.css)
//     derives it from the subform's presence, including one marked for
//     destruction.
//
// A 422 re-render keeps the submitted subforms — Rails re-renders them from the
// invalid object — and the form-wide feedback controller moves focus to the
// first invalid field, so there is nothing to restore here.
export default class extends Controller {
  static targets = ["container", "template"];
  static values = {
    // has_many child-index token to replace on add; empty for singular
    // (has_one/belongs_to) associations, which mark themselves with
    // data-nested-form-singular-value="true" — read only by the skin.css
    // add-control rule, not by this controller.
    placeholder: String,
  };

  static index = 0;

  add(event) {
    event?.preventDefault();
    let html = this.templateTarget.innerHTML;
    if (this.placeholderValue) {
      html = html.replaceAll(this.placeholderValue, this.#nextIndex());
    }
    const fragment = document.createRange().createContextualFragment(html);
    const subform = fragment.firstElementChild;
    this.containerTarget.appendChild(fragment);
    // Stimulus widgets in the new subform (date pickers, selects) auto-connect via
    // the MutationObserver; this fires rails_admin.dom_ready so the dom_ready-based
    // initialisers (rich-text editors) pick up the freshly inserted fields too.
    document.dispatchEvent(
      new CustomEvent("rails_admin.dom_ready", { detail: subform })
    );
    this.#focusFirstField(subform);
  }

  remove(event) {
    event?.preventDefault();
    const subform = event.target.closest("[data-nested-form-target='subform']");
    if (!subform) return;

    if (this.#persisted(subform)) {
      this.#toggleMarkedForDestruction(subform);
    } else {
      subform.remove();
    }
  }

  // A persisted record carries a populated `id` hidden field (Rails emits one
  // automatically for existing nested records); a brand-new subform has none.
  #persisted(subform) {
    const id = subform.querySelector("input[name$='[id]']");
    return Boolean(id && id.value);
  }

  #toggleMarkedForDestruction(subform) {
    const marked = subform.classList.toggle("marked_for_destruction");
    const destroy = subform.querySelector(
      "input[data-nested-form-target='destroy']"
    );
    if (destroy) destroy.value = marked ? "1" : "";
    this.#relaxRequired(subform, marked);
  }

  // Required inputs in a doomed subform must not block native form submission;
  // relax them while marked and restore them if the user un-marks.
  #relaxRequired(subform, marked) {
    if (marked) {
      subform.querySelectorAll("[required]").forEach((input) => {
        input.dataset.nestedFormWasRequired = "true";
        input.required = false;
      });
    } else {
      subform
        .querySelectorAll("[data-nested-form-was-required]")
        .forEach((input) => {
          input.required = true;
          delete input.dataset.nestedFormWasRequired;
        });
    }
  }

  #focusFirstField(subform) {
    const fields = subform.querySelectorAll(
      "input:not([type='hidden']):not([type='submit']):not([type='button']), select, textarea"
    );
    // querySelectorAll does not descend into a nested <template>'s inert
    // content, so deeply-nested blank fields are never matched here.
    const target =
      Array.from(fields).find((field) => field.offsetParent !== null) ||
      fields[0];
    target?.focus();
  }

  #nextIndex() {
    return `${Date.now()}${this.constructor.index++}`;
  }
}
