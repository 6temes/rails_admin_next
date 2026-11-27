import { Controller } from "@hotwired/stimulus";

// Positions the sticky (frozen) columns of a horizontally scrollable list table.
// Each sticky cell is offset by its distance from the first sticky cell in the
// row so the frozen columns stack flush against the left edge while the rest of
// the table scrolls under them. Every row shares the header's column widths, so
// the offsets are measured once on the header row and written to every row.
//
// It runs on connect: Turbo Drive re-inserts #sidescroll on each visit, so the
// controller reconnects and recomputes the offsets automatically without a
// separate dom_ready listener. Rows appended by a later batch take the current
// offsets as they connect, and the whole table is measured again before the
// next paint, since a wider cell in a new row can move every column.
export default class extends Controller {
  static targets = ["row"];

  #offsets;
  #pendingFrame;

  connect() {
    this.#position();
  }

  disconnect() {
    cancelAnimationFrame(this.#pendingFrame);
    this.#pendingFrame = null;
  }

  rowTargetConnected(row) {
    if (!this.#offsets) return;

    this.#apply(row);
    this.#pendingFrame ??= requestAnimationFrame(() => {
      this.#pendingFrame = null;
      this.#position();
    });
  }

  #position() {
    const cells = [...this.element.querySelectorAll("thead tr .sticky")];
    const first = cells[0]?.offsetLeft;
    this.#offsets = cells.map((cell) => cell.offsetLeft - first);
    this.element.querySelectorAll("tr").forEach((row) => this.#apply(row));
  }

  #apply(row) {
    row.querySelectorAll("th.sticky, td.sticky").forEach((cell, index) => {
      cell.style.left = `${this.#offsets[index]}px`;
    });
  }
}
