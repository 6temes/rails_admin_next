import { Controller } from "@hotwired/stimulus";

// Lives on the bulk form of an infinite-scroll list and only writes state:
// the row checkboxes' checkedness is the explicit selection, and the
// all-matching fieldset's `disabled` flag says whether the selection extends
// to every record the filter matches. What the selection bar shows is derived
// from those two in skin.css. Both survive a Turbo snapshot and a
// back/forward-cache restore, so connect() rebuilds everything else from them.
export default class extends Controller {
  static targets = ["allMatching", "count", "header", "row"];
  static values = { selectedCount: String };

  #onPageshow = (event) => {
    if (event.persisted) this.#enableRows();
  };

  connect() {
    this.#enableRows();
    window.addEventListener("pageshow", this.#onPageshow);
    this.#refresh();
  }

  disconnect() {
    window.removeEventListener("pageshow", this.#onPageshow);
  }

  // Rows that arrive with a batch join an all-matching selection ticked.
  rowTargetConnected(row) {
    if (this.#allMatching) row.checked = true;
    this.#refresh();
  }

  rowTargetDisconnected() {
    this.#refresh();
  }

  toggleAll() {
    const checked = this.headerTarget.checked;
    this.rowTargets.forEach((row) => (row.checked = checked));
    if (!checked) this.allMatchingTarget.disabled = true;
    this.#refresh();
  }

  rowChanged(event) {
    if (!event.target.checked) this.allMatchingTarget.disabled = true;
    this.#refresh();
  }

  selectAllMatching() {
    this.allMatchingTarget.disabled = false;
  }

  get #allMatching() {
    return !this.allMatchingTarget.disabled;
  }

  // The bulk menu disables the rows before an all-matching submit, so the
  // request carries no ids; a page restored after that submit needs them back.
  #enableRows() {
    this.rowTargets.forEach((row) => (row.disabled = false));
  }

  #refresh() {
    const rows = this.rowTargets;
    const checked = rows.filter((row) => row.checked).length;
    this.countTarget.textContent = this.selectedCountValue.replace(
      "%{count}",
      checked
    );
    this.headerTarget.checked = rows.length > 0 && checked === rows.length;
    this.headerTarget.indeterminate = checked > 0 && checked < rows.length;
  }
}
