import { Controller } from "@hotwired/stimulus";

// When the polymorphic type <select> changes, swap the object <select>'s
// filtering-select source to the chosen type's options, which makes that
// controller rebuild itself (reload).
//
// Wired by data-controller="polymorphic" + data-action="change->polymorphic#change"
// on the type select; the per-type option blobs live in sibling
// `#<type>-js-options` divs (data-options), and the object select carries
// data-controller="filtering-select".
export default class extends Controller {
  change() {
    const type = this.element.value.toLowerCase().replace(/::/g, "-");
    const row = this.element.closest(".row");
    const optionsEl = row?.querySelector(`#${CSS.escape(type)}-js-options`);
    const objectSelect = row?.querySelector(
      '[data-controller~="filtering-select"]'
    );
    if (!objectSelect || !optionsEl) return;

    objectSelect.setAttribute(
      "data-filtering-select-options-value",
      optionsEl.dataset.options || "{}"
    );
  }
}
