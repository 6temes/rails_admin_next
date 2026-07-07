import { Controller } from "@hotwired/stimulus";

const FOCUSABLE = [
  "a[href]",
  "button:not([disabled])",
  'input:not([disabled]):not([type="hidden"])',
  "select:not([disabled])",
  "textarea:not([disabled])",
  '[tabindex]:not([tabindex="-1"])',
].join(", ");

// Inline-edit dialog on a native <dialog closedby="any">: the platform owns the
// top layer, focus trap, Escape, backdrop light-dismissal, return focus and
// ARIA modality. This controller only fills it with a server-rendered form via
// renderContent() and wires the primary action through the `onSave` callback
// set by RemoteFormController.
//
// Every dismissal — cancel button, Escape, backdrop click, Turbo teardown —
// funnels through the native `close` event, so the reset there (nulling
// `onSave` invalidates in-flight loads, see RemoteFormController#open) cannot
// be bypassed.
export default class extends Controller {
  static targets = ["title", "body", "saveButton", "cancelButton"];

  connect() {
    this.onSave = null;
    // The markup seeds the title with the I18n loading string; keep it to
    // re-seed the loading state on every close.
    this.loadingTitle = this.titleTarget.textContent;
    this.onClose = () => this.#reset();
    this.element.addEventListener("close", this.onClose);
    // Turbo snapshots the DOM as-is, [open] included — but a restored [open]
    // dialog would sit inline, outside the top layer. Close before the
    // snapshot is taken, and on connect in case a stray one got cached anyway.
    this.onBeforeCache = () => this.#dismiss();
    document.addEventListener("turbo:before-cache", this.onBeforeCache);
    this.#dismiss();
  }

  disconnect() {
    this.element.removeEventListener("close", this.onClose);
    document.removeEventListener("turbo:before-cache", this.onBeforeCache);
  }

  open() {
    // showModal() throws if the dialog is already open, so reopening (the
    // shared dialog grabbed for another field) goes through a close first.
    // Caveat for future callers: the `close` event is a QUEUED task, so its
    // reset would run after a caller's synchronous post-open() assignments
    // (nulling a just-set onSave). Unreachable today — an open modal dialog
    // makes the rest of the document inert, so nothing can re-enter open()
    // while it is open — but do not rely on this path without fixing that.
    this.#dismiss();
    this.enableSave();
    this.element.showModal();
  }

  // Swap in a server-rendered form fragment (trusted engine HTML, like a Turbo
  // frame load), copy its title and submit/cancel labels into the chrome, drop
  // the in-form action bar (replaced by the footer) and any nested inline-add
  // controls, then move focus to the first field — autofocus resolved back
  // when showModal() ran, before this async content existed.
  renderContent(html) {
    // A response landing after the dialog was dismissed (e.g. Escape during a
    // slow 422 submit) must not repopulate the reset body — the stale form
    // would resurface, populated, on the next open().
    if (!this.element.open) return;
    this.bodyTarget.innerHTML = html;
    this.bodyTarget.removeAttribute("aria-busy");
    const form = this.bodyTarget.querySelector("form");
    if (form) {
      this.titleTarget.textContent = form.dataset.title || "";
      const save = form.querySelector('[name="_save"]');
      const cancel = form.querySelector('[name="_continue"]');
      if (save) this.saveButtonTarget.innerHTML = save.innerHTML;
      if (cancel) this.cancelButtonTarget.innerHTML = cancel.innerHTML;
      form.querySelectorAll(".form-actions").forEach((node) => node.remove());
    }
    this.bodyTarget
      .querySelectorAll(".modal-actions")
      .forEach((node) => node.remove());
    this.#focusFirst();
  }

  save(event) {
    event?.preventDefault();
    if (this.saveButtonTarget.classList.contains("disabled")) return;
    this.onSave?.();
  }

  close(event) {
    event?.preventDefault();
    this.#dismiss();
  }

  // The Save anchor has no native `disabled` — RemoteFormController toggles
  // this around its fetch so a second click (or Enter) while a submit is in
  // flight is a no-op instead of a second POST.
  disableSave() {
    this.saveButtonTarget.classList.add("disabled");
    this.saveButtonTarget.setAttribute("aria-disabled", "true");
    this.element.setAttribute("aria-busy", "true");
  }

  enableSave() {
    this.saveButtonTarget.classList.remove("disabled");
    this.saveButtonTarget.removeAttribute("aria-disabled");
    this.element.removeAttribute("aria-busy");
  }

  #dismiss() {
    if (this.element.open) this.element.close();
  }

  // Runs on the native `close` event, whatever triggered it. Nulling `onSave`
  // is the stale-load guard's reset; the rest returns the chrome to the seeded
  // loading state (busy empty body, loading title, interactive Save) so the
  // next open() starts clean even after a mid-submit dismissal.
  #reset() {
    this.onSave = null;
    this.enableSave();
    this.bodyTarget.replaceChildren();
    this.bodyTarget.setAttribute("aria-busy", "true");
    this.titleTarget.textContent = this.loadingTitle;
  }

  #focusable() {
    return Array.from(this.bodyTarget.querySelectorAll(FOCUSABLE)).filter(
      (el) => el.offsetParent !== null || el === document.activeElement
    );
  }

  // First errored field on a 422 re-render (its wrapper is marked
  // .control-group.error server-side), first field otherwise. With nothing
  // focusable in the body, the focus showModal() placed on the chrome stands.
  #focusFirst() {
    const fields = this.#focusable();
    const target =
      fields.find((el) => el.closest(".control-group.error")) || fields[0];
    target?.focus();
  }
}
