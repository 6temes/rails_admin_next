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

const SEARCH_DELAY = 400;

// Dual-list widget over a hidden <select multiple> (the real form field). The
// left "collection" lists candidates, the right "selection" lists chosen
// records; add/remove/choose-all/clear-all move <option>s between them and
// keep the hidden select (the submitted value) in sync. Sortable (up/down)
// reorders the selection. The filter box searches a local cache or a remote
// source.
//
// The rendered DOM keeps the class/title hooks the inline-add flow
// (remote-form.js), the specs, and the CSS depend on (.ra-multiselect,
// .ra-multiselect-collection/-selection/-search/-center, the add/remove links).
//
// Wired by data-controller="filtering-multiselect" on the <select>, with
// data-filtering-multiselect-options-value = { xhr, remote_source, scopeBy,
// sortable, removable, cacheAll, regional }.
export default class extends Controller {
  static values = { options: { type: Object, default: {} } };

  connect() {
    this.select = this.element;
    this.cache = {};
    this.searchTimer = null;
    this.requestId = 0;
    this.#build();
    this.#buildCache();
    this.#bind();
  }

  disconnect() {
    clearTimeout(this.searchTimer);
    this.wrapper?.remove();
    this.select.style.display = "";
  }

  get #regional() {
    return this.optionsValue.regional || {};
  }

  // Defaults: removable on, sortable off, unless the options say otherwise (the
  // enum js_data omits both keys).
  get #removable() {
    return this.optionsValue.removable !== false;
  }

  get #sortable() {
    return this.optionsValue.sortable === true;
  }

  #build() {
    const id = this.select.id;
    this.element.parentNode
      .querySelectorAll(`.ra-multiselect[data-input-for="${CSS.escape(id)}"]`)
      .forEach((node) => node.remove());

    this.wrapper = el("div", { class: "ra-multiselect", "data-input-for": id });
    this.select.after(this.wrapper);

    this.search = el("input", {
      type: "search",
      class: "form-control ra-multiselect-search",
      placeholder: this.#regional.search || "",
      "aria-label": this.#regional.search || "Search",
    });
    this.wrapper.appendChild(
      el("div", { class: "ra-multiselect-header" }, this.search)
    );

    const left = el("div", {
      class: "ra-multiselect-column ra-multiselect-left",
    });
    const center = el("div", {
      class: "ra-multiselect-column ra-multiselect-center",
    });
    const right = el("div", {
      class: "ra-multiselect-column ra-multiselect-right",
    });
    this.wrapper.append(left, center, right);

    this.collection = el("select", {
      class: "form-control ra-multiselect-collection",
      multiple: "multiple",
      "aria-label": this.#regional.search || "Available",
    });
    this.addAll = el(
      "a",
      { href: "#", class: "ra-multiselect-item-add-all" },
      icon("move_right"),
      this.#regional.chooseAll || ""
    );
    left.append(el("div", { class: "wrapper" }, this.collection), this.addAll);

    this.add = el(
      "a",
      {
        href: "#",
        class: "ra-multiselect-item-add",
        title: this.#regional.add,
        role: "button",
        "aria-label": this.#regional.add,
      },
      icon("move_right")
    );
    center.appendChild(this.add);
    if (this.#removable) {
      this.remove = el(
        "a",
        {
          href: "#",
          class: "ra-multiselect-item-remove",
          title: this.#regional.remove,
          role: "button",
          "aria-label": this.#regional.remove,
        },
        icon("move_left")
      );
      center.appendChild(this.remove);
    }
    if (this.#sortable) {
      this.up = el(
        "a",
        {
          href: "#",
          class: "ra-multiselect-item-up",
          title: this.#regional.up,
          role: "button",
          "aria-label": this.#regional.up,
        },
        icon("move_up")
      );
      this.down = el(
        "a",
        {
          href: "#",
          class: "ra-multiselect-item-down",
          title: this.#regional.down,
          role: "button",
          "aria-label": this.#regional.down,
        },
        icon("move_down")
      );
      center.append(this.up, this.down);
    }

    this.selection = el("select", {
      class: "form-control ra-multiselect-selection",
      multiple: "multiple",
      "aria-label": "Selected",
    });
    right.appendChild(el("div", { class: "wrapper" }, this.selection));
    if (this.#removable) {
      this.removeAll = el(
        "a",
        { href: "#", class: "ra-multiselect-item-remove-all" },
        icon("move_left"),
        this.#regional.clearAll || ""
      );
      right.appendChild(this.removeAll);
    }

    this.status = el("div", {
      class: "ra-multiselect-status visually-hidden",
      role: "status",
      "aria-live": "polite",
    });
    this.wrapper.appendChild(this.status);

    this.select.style.display = "none";

    if (this.optionsValue.xhr) {
      this.collection.appendChild(
        this.#placeholder(I18n.t("too_many_objects"))
      );
    }
  }

  #placeholder(text) {
    return el("option", { disabled: "disabled" }, text);
  }

  // Cache every option (preserving insertion order) and split the live options
  // into the selection (chosen) and collection (candidate) lists.
  #buildCache() {
    Array.from(this.select.options).forEach((option) => {
      this.cache[`o_${option.value}`] = {
        id: option.value,
        value: option.text,
      };
      const clone = option.cloneNode(true);
      clone.selected = false;
      clone.title = option.text;
      (option.selected ? this.selection : this.collection).appendChild(clone);
    });
  }

  #bind() {
    this.addAll.addEventListener("click", (e) => {
      e.preventDefault();
      this.#select(
        Array.from(this.collection.querySelectorAll("option:not(:disabled)"))
      );
      this.#announceCounts();
    });
    this.add.addEventListener("click", (e) => {
      e.preventDefault();
      this.#select(Array.from(this.collection.selectedOptions));
      this.#announceCounts();
    });
    if (this.#removable) {
      this.removeAll.addEventListener("click", (e) => {
        e.preventDefault();
        this.#deselect(Array.from(this.selection.options));
        this.#announceCounts();
      });
      this.remove.addEventListener("click", (e) => {
        e.preventDefault();
        this.#deselect(Array.from(this.selection.selectedOptions));
        this.#announceCounts();
      });
    }
    if (this.#sortable) {
      this.up.addEventListener("click", (e) => {
        e.preventDefault();
        this.#move("up", Array.from(this.selection.selectedOptions));
      });
      this.down.addEventListener("click", (e) => {
        e.preventDefault();
        this.#move("down", Array.from(this.selection.selectedOptions));
      });
    }
    this.search.addEventListener("keyup", () => this.#scheduleFilter());
    this.search.addEventListener("click", () => this.#scheduleFilter());
  }

  #scheduleFilter() {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(
      () => this.#queryFilter(this.search.value),
      SEARCH_DELAY
    );
  }

  #queryFilter(value) {
    this.#query(value, (matches) => {
      const fresh = matches.filter((match) => !this.#isSelected(match.id));
      if (fresh.length > 0) {
        this.collection.replaceChildren(
          ...fresh.map((match) => {
            const option = el("option", {
              value: match.id,
              title: match.label,
            });
            option.text = match.label;
            return option;
          })
        );
      } else {
        this.collection.replaceChildren(
          this.#placeholder(I18n.t("no_objects"))
        );
      }
    });
  }

  #query(query, success) {
    if (query === "") {
      if (this.optionsValue.xhr) {
        this.collection.replaceChildren(
          this.#placeholder(I18n.t("too_many_objects"))
        );
        return;
      }
      success(
        Object.values(this.cache).map((o) => ({ id: o.id, label: o.value }))
      );
      return;
    }

    if (this.optionsValue.xhr) {
      const id = ++this.requestId;
      this.controller?.abort();
      this.controller = new AbortController();
      const params = createScopedQuery(this.optionsValue.scopeBy, query);
      const url = `${this.optionsValue.remote_source}&${toQueryString(params)}`;
      fetchJson(url, { signal: this.controller.signal })
        .then((data) => {
          if (id !== this.requestId) return;
          success(data);
        })
        .catch((error) => {
          if (error.name === "AbortError" || id !== this.requestId) return;
          this.collection.replaceChildren(
            this.#placeholder(I18n.t("no_objects"))
          );
        });
      return;
    }

    const matcher = new RegExp(`${escapeRegex(query)}.*`, "i");
    success(
      Object.values(this.cache)
        .filter((o) => matcher.test(o.value))
        .map((o) => ({ id: o.id, label: o.value }))
    );
  }

  // Move options into the selection list and mark them selected on the hidden
  // <select> (appending an <option> if it isn't already there).
  #select(options) {
    options.forEach((option) => {
      const existing = Array.from(this.select.options).find(
        (o) => o.value === option.value
      );
      if (existing) {
        existing.selected = true;
      } else {
        const created = el("option", { value: option.value });
        created.selected = true;
        this.select.appendChild(created);
      }
      this.selection.appendChild(option);
      option.selected = false;
    });
    this.select.dispatchEvent(new Event("change", { bubbles: true }));
  }

  #deselect(options) {
    options.forEach((option) => {
      const existing = Array.from(this.select.options).find(
        (o) => o.value === option.value
      );
      if (existing) existing.selected = false;
      this.collection.appendChild(option);
      option.selected = false;
    });
    this.select.dispatchEvent(new Event("change", { bubbles: true }));
  }

  #move(direction, options) {
    const ordered = direction === "up" ? options : options.reverse();
    ordered.forEach((option) => {
      const sibling =
        direction === "up"
          ? option.previousElementSibling
          : option.nextElementSibling;
      if (!sibling) return;
      const hidden = this.#hiddenOption(option.value);
      const hiddenSibling = this.#hiddenOption(sibling.value);
      if (direction === "up") {
        sibling.before(option);
        if (hidden && hiddenSibling) hiddenSibling.before(hidden);
      } else {
        sibling.after(option);
        if (hidden && hiddenSibling) hiddenSibling.after(hidden);
      }
    });
    this.#announce(`${this.selection.selectedOptions.length} moved`);
  }

  #hiddenOption(value) {
    return Array.from(this.select.options).find((o) => o.value === value);
  }

  #isSelected(value) {
    return Array.from(this.selection.options).some((o) => o.value === value);
  }

  #announceCounts() {
    this.#announce(`${this.selection.options.length} selected`);
  }

  #announce(message) {
    if (this.status) this.status.textContent = message;
  }
}
