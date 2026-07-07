import { Controller } from "@hotwired/stimulus";

const ACCEPT_FORM = "text/javascript";
const ACCEPT_SUBMIT = "application/json, text/javascript";

// Inline create/edit of associated records. Attached to the .row wrapping an
// association's hidden <select> and its add/edit links. Clicking "Add a new …"
// (or "Edit this …", or double-clicking a multiselect option) loads the
// server-rendered new/edit form into the shared modal; submitting goes through
// the modal and, on success, injects the saved record straight into the select.
// Validation errors re-render the form in the modal in place.
export default class extends Controller {
  static outlets = ["modal"];

  connect() {
    // The modal renders the same association partials, so its forms also carry
    // this controller — but nested inline-add is not supported, so skip it.
    if (this.element.closest("#modal")) return;
    this.element.addEventListener("click", this.onClick);
    this.element.addEventListener("dblclick", this.onDblclick);
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick);
    this.element.removeEventListener("dblclick", this.onDblclick);
  }

  onClick = (event) => {
    const create = event.target.closest(".create");
    if (create) {
      event.preventDefault();
      this.#open(create.dataset.link);
      return;
    }
    const update = event.target.closest(".update");
    if (update) {
      event.preventDefault();
      if (update.classList.contains("disabled")) return;
      const value = this.#select?.value;
      if (value) this.#open(update.dataset.link.replace("__ID__", value));
    }
  };

  onDblclick = (event) => {
    const option = event.target.closest("option");
    if (!option || option.disabled || !option.closest(".ra-multiselect"))
      return;
    const editUrl = this.#editUrl;
    if (editUrl) this.#open(editUrl.replace("__ID__", option.value));
  };

  async #open(url) {
    if (!this.hasModalOutlet) return;
    const modal = this.modalOutlet;
    modal.open();
    const onSave = () => this.#submit();
    modal.onSave = onSave;
    this.loadAbortController?.abort();
    const controller = (this.loadAbortController = new AbortController());
    try {
      const html = await this.#load(url, controller.signal);
      // The modal is shared by every association field. If it was dismissed or
      // reopened for a different field while this request was in flight,
      // `modal.onSave` no longer points at the callback we just set — discard
      // the response instead of rendering a stale form under someone else's
      // Save handler (and injecting into the wrong hidden select).
      if (modal.onSave !== onSave) return;
      modal.renderContent(html);
    } catch (error) {
      if (error.name === "AbortError") return;
      modal.close();
    }
  }

  async #load(url, signal) {
    const response = await fetch(url, {
      headers: { Accept: ACCEPT_FORM, "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin",
      signal,
    });
    return response.text();
  }

  async #submit() {
    const modal = this.modalOutlet;
    // Same staleness guard as #open: if the shared modal was dismissed or
    // reopened for another field while this request was in flight,
    // `modal.onSave` no longer points at this field's callback and the modal
    // chrome must be left alone. Deliberately no AbortController here — a
    // submit that reached the server saves the record regardless, and the
    // response must still be injected into this field's row.
    const onSave = modal.onSave;
    modal.disableSave();
    try {
      const form = modal.bodyTarget.querySelector("form");
      if (!form) return;
      const response = await fetch(form.action, {
        method: form.method,
        headers: {
          Accept: ACCEPT_SUBMIT,
          "X-Requested-With": "XMLHttpRequest",
        },
        body: new FormData(form),
        credentials: "same-origin",
      });
      if (
        response.ok &&
        response.headers.get("Content-Type")?.includes("json")
      ) {
        // Always inject — #inject targets this.element (the submitting
        // field's own row), not the modal, so the saved record lands in the
        // right select even if the modal has moved on.
        this.#inject(await response.json());
        if (modal.onSave === onSave) modal.close();
      } else if (modal.onSave === onSave) {
        modal.renderContent(await response.text());
      }
    } catch (error) {
      if (modal.onSave === onSave) modal.close();
    } finally {
      if (modal.onSave === onSave) modal.enableSave();
    }
  }

  // Place the saved record into the field's hidden <select> (the submitted value)
  // and reflect it in the visible widget.
  #inject({ id, label }) {
    const select = this.#select;
    if (!select) return;
    const multiselect = this.element.querySelector(".ra-multiselect");
    if (multiselect) {
      const existing = multiselect.querySelector(`option[value="${id}"]`);
      if (existing) {
        select
          .querySelectorAll(`option[value="${id}"]`)
          .forEach((option) => (option.text = label));
        multiselect
          .querySelectorAll(`option[value="${id}"]`)
          .forEach((option) => (option.text = label));
      } else {
        select.add(new Option(label, id, true, true));
        multiselect
          .querySelector("select.ra-multiselect-selection")
          ?.add(new Option(label, id));
      }
    } else {
      const input = this.element.querySelector(".ra-filtering-select-input");
      if (input) input.value = label;
      if (select.querySelector(`option[value="${id}"]`)) {
        Array.from(select.options).forEach(
          (option) => (option.selected = option.value === String(id))
        );
      } else {
        select.replaceChildren(new Option(label, id, true, true));
      }
      this.element.querySelector(".update")?.classList.remove("disabled");
    }
  }

  get #select() {
    return this.element.querySelector("select");
  }

  get #editUrl() {
    const options = this.#select?.dataset.options;
    if (!options) return null;
    try {
      return JSON.parse(options)["edit-url"] || null;
    } catch {
      return null;
    }
  }
}
