import { Controller } from "@hotwired/stimulus";
import I18n from "rails_admin/i18n";
import { icon } from "rails_admin/icons";
import { el } from "rails_admin/dom";
import {
  createScopedQuery,
  toQueryString,
  escapeRegex,
  fetchJson,
} from "rails_admin/select_query";

const SEARCH_DELAY = 200;

let sequence = 0;

// Accessible combobox over a hidden <select> (the real form field), following
// the WAI-ARIA APG combobox + listbox pattern: role=combobox input with
// aria-expanded / aria-activedescendant driving a role=listbox of role=option
// items, arrow/Enter/Escape/Home/End keys, and aria-live regions for the
// empty and error states.
//
// Wired by data-controller="filtering-select" on the <select>, with
// data-filtering-select-options-value = { xhr, remoteSource, scopeBy }.
//
// The rendered DOM keeps the class hooks the inline-add flow (remote-form.js)
// and the existing CSS depend on: `.filtering-select[data-input-for]`,
// `.ra-filtering-select-input`, `.dropdown-toggle`.
export default class extends Controller {
  static values = { options: { type: Object, default: {} } };

  connect() {
    this.select = this.element;
    this.activeIndex = -1;
    this.items = [];
    this.requestId = 0;
    this.#build();
  }

  disconnect() {
    // Remove the generated UI and restore the <select> so a Turbo snapshot
    // caches the original markup — this is what prevents a duplicate combobox
    // from being restored on browser back/forward.
    clearTimeout(this.searchTimer);
    this.#teardown();
    this.group?.remove();
    this.select.style.display = "";
    this.select.removeAttribute("data-ra-filtering-select-built");
  }

  // Re-initialise against a fresh option set / remote source (used by the
  // polymorphic type switch): tears down and fully rebuilds the field.
  reload() {
    this.#teardown();
    this.group?.remove();
    this.select.innerHTML = '<option value="" selected="selected"></option>';
    this.#build();
  }

  // Remove the document-level outside-click listener bound in #bind(). Without
  // this, every reload() (each polymorphic type switch) would add a new listener
  // on top of the previous one, leaking a permanent handler closing over
  // removed DOM.
  #teardown() {
    if (this.outsideHandler)
      document.removeEventListener("click", this.outsideHandler);
  }

  #build() {
    const id = this.select.id;

    // Reuse an orphaned group from a bfcache snapshot rather than duplicating it.
    this.element.parentNode
      .querySelectorAll(`.filtering-select[data-input-for="${CSS.escape(id)}"]`)
      .forEach((node) => node.remove());

    // Capture the select's own style BEFORE hiding it — and after clearing any
    // display we set on a previous build (reload) — so we never copy display:none
    // onto the visible combobox input.
    this.select.style.display = "";
    const selectStyle = this.select.getAttribute("style");
    this.select.style.display = "none";
    this.select.setAttribute("data-ra-filtering-select-built", "true");

    const selected = this.select.options[this.select.selectedIndex];
    const value = selected && selected.value ? selected.text : "";

    this.listId = `ra-fs-list-${(sequence += 1)}`;
    this.statusId = `ra-fs-status-${sequence}`;

    this.group = el("div", {
      class: "input-group filtering-select",
      "data-input-for": id,
    });

    this.input = el("input", {
      type: "text",
      class: "form-control ra-filtering-select-input",
      role: "combobox",
      "aria-autocomplete": "list",
      "aria-expanded": "false",
      "aria-controls": this.listId,
      "aria-describedby": this.statusId,
      autocomplete: "off",
    });
    this.input.value = value;
    if (selectStyle) {
      this.input.setAttribute("style", selectStyle);
    }
    if (this.select.getAttribute("placeholder")) {
      this.input.setAttribute(
        "placeholder",
        this.select.getAttribute("placeholder")
      );
    }
    // Move `required` off the hidden <select> (it can't be validated while hidden).
    if (this.select.hasAttribute("required")) {
      this.required = true;
      this.input.setAttribute("required", "required");
      this.select.removeAttribute("required");
    }

    this.button = el("label", {
      class: "btn btn-info dropdown-toggle",
      role: "button",
      title: "Show All Items",
      "aria-label": "Show All Items",
    });
    this.buttonWrap = el("span", { class: "input-group-btn" }, this.button);

    this.menu = el("ul", {
      class: "ra-filtering-select-menu",
      id: this.listId,
      role: "listbox",
      hidden: true,
    });
    Object.assign(this.menu.style, {
      position: "absolute",
      zIndex: "1000",
      top: "100%",
      left: "0",
      right: "0",
      margin: "0",
      padding: "0",
      listStyle: "none",
      background: "#fff",
      border: "1px solid rgba(0,0,0,.15)",
      maxHeight: "16rem",
      overflowY: "auto",
    });

    this.status = el("div", {
      id: this.statusId,
      class: "ra-filtering-select-status visually-hidden",
      role: "status",
      "aria-live": "polite",
    });

    this.error = el("div", {
      class: "ra-filtering-select-error text-danger",
      role: "alert",
      "aria-live": "assertive",
      hidden: true,
    });

    this.group.append(
      this.input,
      this.buttonWrap,
      this.menu,
      this.status,
      this.error
    );
    this.group.style.position = "relative";
    this.select.after(this.group);

    this.#bind();
  }

  #bind() {
    this.input.addEventListener("input", () => {
      // Emptying the box clears the current selection.
      if (this.input.value.length === 0) this.#clear();
      this.#scheduleSearch(this.input.value);
    });
    this.input.addEventListener("keydown", (e) => this.#onKeydown(e));
    this.input.addEventListener("blur", () => this.#onBlur());
    this.button.addEventListener("click", (e) => {
      e.preventDefault();
      this.#onToggle();
    });
    this.outsideHandler = (e) => {
      if (this.group && !this.group.contains(e.target)) this.#close();
    };
    document.addEventListener("click", this.outsideHandler);
  }

  #scheduleSearch(term) {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.#search(term), SEARCH_DELAY);
  }

  #onToggle() {
    if (!this.menu.hidden) {
      this.#close();
      return;
    }
    this.#search("");
    this.input.focus();
  }

  #search(term) {
    this.#query(term, (results, isRemote) =>
      this.#renderMenu(this.#resultSet(term, results, isRemote))
    );
  }

  // Resolve the source: local (the <select>'s own options) or remote (xhr).
  #query(term, done) {
    if (this.optionsValue.xhr) {
      this.#remoteQuery(term, done);
    } else {
      const source = Array.from(this.select.options)
        .filter((o) => o.value !== "")
        .map((o) => ({ label: o.text, value: o.value }));
      const matcher = new RegExp(escapeRegex(term), "i");
      done(
        source.filter((el) => matcher.test(el.label)),
        false
      );
    }
  }

  #remoteQuery(term, done) {
    const id = ++this.requestId;
    this.controller?.abort();
    this.controller = new AbortController();
    this.#setBusy(true);
    this.error.hidden = true;

    const query = createScopedQuery(this.optionsValue.scopeBy, term);
    const url = `${this.optionsValue.remote_source}&${toQueryString(query)}`;

    fetchJson(url, { signal: this.controller.signal })
      .then((data) => {
        if (id !== this.requestId) return;
        this.#setBusy(false);
        done(data, true);
      })
      .catch((error) => {
        if (error.name === "AbortError" || id !== this.requestId) return;
        this.#setBusy(false);
        this.#renderError();
      });
  }

  // Build the list of menu entries: a leading "Clear" entry on an empty,
  // optional field; a disabled "no objects" entry when nothing matches;
  // otherwise the (highlighted) matches.
  #resultSet(term, data, isRemote) {
    const matcher = new RegExp(escapeRegex(term), "i");
    const matches = data
      .map((el) => {
        const id = el.id || el.value;
        const label = el.label || el.id;
        if (id && (isRemote || matcher.test(el.label))) {
          return { id, value: label, term };
        }
        return null;
      })
      .filter(Boolean);

    if (term.length === 0 && !this.required) {
      return [{ clear: true }, ...matches];
    }
    if (matches.length === 0) {
      return [{ empty: true }];
    }
    return matches;
  }

  #renderMenu(entries) {
    this.menu.replaceChildren();
    this.items = [];
    this.activeIndex = -1;

    entries.forEach((entry) => {
      const li = document.createElement("li");
      li.id = `${this.listId}-opt-${this.items.length}`;
      li.setAttribute("role", "option");
      li.setAttribute("aria-selected", "false");
      li.className = "ra-filtering-select-option";
      Object.assign(li.style, { padding: ".25rem .75rem", cursor: "pointer" });

      if (entry.empty) {
        li.setAttribute("aria-disabled", "true");
        li.classList.add("ra-filtering-select-empty");
        li.textContent = I18n.t("no_objects");
        li.style.cursor = "default";
        this.#announce(I18n.t("no_objects"));
      } else if (entry.clear) {
        li.dataset.clear = "true";
        li.append(icon("cancel"), ` ${I18n.t("clear")}`);
        li.addEventListener("mousedown", (e) => e.preventDefault());
        li.addEventListener("click", () => this.#choose(li));
        this.items.push({ el: li, id: null, value: null });
      } else {
        li.dataset.value = entry.id;
        li.dataset.label = entry.value;
        li.append(...this.#highlight(entry.value, entry.term));
        li.addEventListener("mousedown", (e) => e.preventDefault());
        li.addEventListener("click", () => this.#choose(li));
        this.items.push({ el: li, id: entry.id, value: entry.value });
      }
      this.menu.appendChild(li);
    });

    this.#open();
  }

  #renderError() {
    this.menu.replaceChildren();
    this.items = [];
    this.error.replaceChildren();
    const message = document.createElement("span");
    message.textContent = I18n.t("no_objects");
    const retry = document.createElement("button");
    retry.type = "button";
    retry.className = "btn btn-link btn-sm ra-filtering-select-retry";
    retry.textContent = I18n.t("retry");
    retry.addEventListener("click", (e) => {
      e.preventDefault();
      this.#search(this.input.value);
    });
    this.error.append(message, " ", retry);
    this.error.hidden = false;
    this.#close();
  }

  // Split `label` on `term` and wrap the matched term in <strong>, building DOM
  // text nodes (never innerHTML) so server-supplied labels can't inject markup.
  #highlight(label, term) {
    if (!term || !term.length) return [document.createTextNode(label)];
    const matcher = new RegExp(escapeRegex(term), "i");
    const nodes = [];
    let rest = label;
    let match;
    while ((match = rest.match(matcher)) && match[0].length) {
      const index = match.index;
      if (index > 0) nodes.push(document.createTextNode(rest.slice(0, index)));
      const strong = document.createElement("strong");
      strong.textContent = rest.slice(index, index + match[0].length);
      nodes.push(strong);
      rest = rest.slice(index + match[0].length);
    }
    if (rest.length) nodes.push(document.createTextNode(rest));
    return nodes;
  }

  #choose(li) {
    if (li.dataset.clear) {
      this.#clear();
      this.#close();
      return;
    }
    const id = li.dataset.value;
    const label = li.dataset.label;

    let option = Array.from(this.select.options).find((o) => o.value === id);
    this.select
      .querySelectorAll("option[selected]")
      .forEach((o) => (o.selected = false));
    if (option) {
      option.selected = true;
    } else {
      option = document.createElement("option");
      option.value = id;
      option.selected = true;
      option.text = label;
      this.select.appendChild(option);
    }
    this.input.value = label;
    this.select.dispatchEvent(new Event("change", { bubbles: true }));
    this.#enableInlineEdit(true);
    this.#close();
    this.input.focus();
  }

  // Deselect without destroying the option list, so the candidate set survives a
  // browser back/forward restore.
  #clear() {
    this.input.value = "";
    this.select
      .querySelectorAll("option[selected]")
      .forEach((o) => (o.selected = false));
    let blank = Array.from(this.select.options).find((o) => o.value === "");
    if (!blank) {
      blank = document.createElement("option");
      blank.value = "";
      this.select.insertBefore(blank, this.select.firstChild);
    }
    blank.selected = true;
    this.select.value = "";
    this.select.dispatchEvent(new Event("change", { bubbles: true }));
    this.#enableInlineEdit(false);
  }

  #onKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        if (this.menu.hidden) this.#search(this.input.value);
        else this.#move(1);
        break;
      case "ArrowUp":
        event.preventDefault();
        this.#move(-1);
        break;
      case "Home":
        if (!this.menu.hidden) {
          event.preventDefault();
          this.#activate(0);
        }
        break;
      case "End":
        if (!this.menu.hidden) {
          event.preventDefault();
          this.#activate(this.items.length - 1);
        }
        break;
      case "Enter":
        if (!this.menu.hidden && this.activeIndex >= 0) {
          event.preventDefault();
          this.#choose(this.items[this.activeIndex].el);
        }
        break;
      case "Escape":
        if (!this.menu.hidden) {
          event.preventDefault();
          this.#close();
        }
        break;
      default:
        break;
    }
  }

  #onBlur() {
    // Revert a half-typed, uncommitted query back to the committed selection's
    // label so the input never shows a value the <select> doesn't hold.
    setTimeout(() => {
      if (this.group && this.group.contains(document.activeElement)) return;
      const selected = this.select.options[this.select.selectedIndex];
      const label = selected && selected.value ? selected.text : "";
      if (this.input.value !== label) this.input.value = label;
      this.#close();
    }, 150);
  }

  #move(direction) {
    if (this.items.length === 0) return;
    let index = this.activeIndex + direction;
    if (index < 0) index = this.items.length - 1;
    if (index >= this.items.length) index = 0;
    this.#activate(index);
  }

  #activate(index) {
    this.items.forEach(({ el }) => {
      el.classList.remove("active");
      el.setAttribute("aria-selected", "false");
    });
    this.activeIndex = index;
    const { el } = this.items[index];
    el.classList.add("active");
    el.setAttribute("aria-selected", "true");
    el.scrollIntoView({ block: "nearest" });
    this.input.setAttribute("aria-activedescendant", el.id);
  }

  #open() {
    this.menu.hidden = false;
    this.input.setAttribute("aria-expanded", "true");
  }

  #close() {
    this.menu.hidden = true;
    this.input.setAttribute("aria-expanded", "false");
    this.input.removeAttribute("aria-activedescendant");
    this.activeIndex = -1;
  }

  #setBusy(busy) {
    this.input.setAttribute("aria-busy", busy ? "true" : "false");
    this.group.classList.toggle("ra-filtering-select-busy", busy);
  }

  #announce(message) {
    this.status.textContent = message;
  }

  #enableInlineEdit(enabled) {
    const controls = this.select.closest(".controls");
    controls?.querySelector(".update")?.classList.toggle("disabled", !enabled);
  }

  optionsValueChanged() {
    // The polymorphic controller swaps this in; rebuild against the new source.
    if (this.group) this.reload();
  }
}
