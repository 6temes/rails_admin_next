import { Controller } from "@hotwired/stimulus";

// Positions the sticky (frozen) columns of a horizontally scrollable list table.
// Each sticky cell is offset by its distance from the first sticky cell in the
// row so the frozen columns stack flush against the left edge while the rest of
// the table scrolls under them.
//
// It runs on connect: Turbo Drive re-inserts #sidescroll on each visit, so the
// controller reconnects and recomputes the offsets automatically without a
// separate dom_ready listener.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("tr").forEach((tr) => {
      let firstPosition;
      tr.querySelectorAll("th.sticky, td.sticky").forEach((cell, index) => {
        if (index === 0) {
          firstPosition = cell.offsetLeft;
        }
        cell.style.left = `${cell.offsetLeft - firstPosition}px`;
      });
    });
  }
}
