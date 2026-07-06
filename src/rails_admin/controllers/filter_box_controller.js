import { Controller } from "@hotwired/stimulus";
import I18n from "rails_admin/i18n";
import { icon } from "rails_admin/icons";
import { el } from "rails_admin/dom";

function option(value, text, attrs = {}) {
  const node = el("option", { value, ...attrs });
  if (text != null) node.textContent = text;
  return node;
}

// Attached to #filters_box, it renders the pre-existing filters (from the `f`
// query params, serialized into data-options) on connect, and — via
// document-level delegation (the "Add filter" menu lives in the navbar, far
// from #filters_box) — appends/removes filter rows and toggles enum
// multi-select mode. Visibility is not mirrored here: the hr.filters_box divider
// and each row's additional value fieldsets are derived by :has() CSS (skin.css)
// from the rows and their operator <select> state.
export default class extends Controller {
  connect() {
    this.box = this.element;

    this.onAdd = (e) => {
      const link = e.target.closest("#filters a");
      if (!link) return;
      e.preventDefault();
      this.#append({
        index: Date.now().toString().slice(6, 11),
        ...JSON.parse(link.dataset.options),
      });
    };
    this.onDelete = (e) => {
      const del = e.target.closest("#filters_box .delete");
      if (!del) return;
      e.preventDefault();
      del.closest(".filter")?.remove();
    };
    this.onSwitchSelect = (e) => {
      const sw = e.target.closest("#filters_box .switch-select");
      if (!sw) return;
      e.preventDefault();
      this.#switchSelect(sw);
    };

    document.addEventListener("click", this.onAdd);
    document.addEventListener("click", this.onDelete);
    document.addEventListener("click", this.onSwitchSelect);

    this.#renderInitial();
  }

  disconnect() {
    document.removeEventListener("click", this.onAdd);
    document.removeEventListener("click", this.onDelete);
    document.removeEventListener("click", this.onSwitchSelect);
    // Clear so a browser back/forward restore doesn't double-render the filters.
    this.box.replaceChildren();
  }

  #renderInitial() {
    this.box.replaceChildren();
    let initial = [];
    try {
      initial = JSON.parse(this.box.dataset.options || "[]");
    } catch {
      initial = [];
    }
    initial.forEach((options) => this.#append(options));
  }

  #append(options) {
    const fieldLabel = options.label;
    const fieldName = options.name;
    const fieldType = options.type;
    const fieldValue = options.value || "";
    const fieldOperator = options.operator;
    const operators = options.operators || [];
    const index = options.index;
    const valueName = `f[${fieldName}][${index}][v]`;
    const operatorName = `f[${fieldName}][${index}][o]`;

    let control = null;
    let additional = null;

    if (operators.length > 0) {
      control = el("select", {
        class: "form-control form-select form-select-sm",
        name: operatorName,
      });
      operators.forEach((operator) => {
        const element = this.#buildOperator(operator, options);
        if (!element) return;
        if (element.getAttribute("value") === fieldOperator)
          element.selected = true;
        control.appendChild(element);
      });
      if (control.querySelector("[data-additional-fieldset]")) {
        control.classList.add("switch-additional-fieldsets");
      }
    }

    switch (fieldType) {
      case "boolean":
        if (control) {
          control.setAttribute("name", valueName);
          control.querySelectorAll("option").forEach((o) => {
            if (o.getAttribute("value") === fieldValue) o.selected = true;
          });
        }
        break;
      case "date":
      case "datetime":
      case "timestamp":
      case "time": {
        // Native HTML5 inputs accept/emit ISO only: date → %Y-%m-%d,
        // time → %H:%M:%S (step=1 keeps seconds), datetime/timestamp → %Y-%m-%dT%H:%M:%S.
        const nativeType =
          fieldType === "date"
            ? "date"
            : fieldType === "time"
            ? "time"
            : "datetime-local";
        additional = [undefined, "-∞", "∞"].map((placeholder, i) => {
          const input = el("input", {
            class: `input-sm form-control form-control-sm ${
              fieldType === "date" ? "date" : "datetime"
            }`,
            type: nativeType,
            step: nativeType === "date" ? null : 1,
            name: `${valueName}[]`,
            value: (fieldValue[i] ?? "") || "",
            placeholder,
          });
          return el(
            "span",
            { class: `additional-fieldset ${i === 0 ? "default" : "between"}` },
            input
          );
        });
        break;
      }
      case "enum":
        if (control) {
          const multiple = Array.isArray(fieldValue);
          control.setAttribute("name", multiple ? `${valueName}[]` : valueName);
          if (multiple) control.setAttribute("multiple", "multiple");
          control.querySelectorAll("option").forEach((o) => {
            const value = o.getAttribute("value");
            if (multiple ? fieldValue.includes(value) : value === fieldValue)
              o.selected = true;
          });
          if (multiple) this.#setValuelessOptionsHidden(control, true);
          const toggle = el(
            "a",
            { href: "#", class: "switch-select" },
            icon(multiple ? "minus" : "plus")
          );
          control = [control, toggle];
        }
        break;
      case "citext":
      case "string":
      case "text":
      case "belongs_to_association":
      case "has_one_association":
        additional = el("input", {
          class: "additional-fieldset form-control form-control-sm",
          type: "text",
          name: valueName,
          value: fieldValue,
        });
        break;
      case "integer":
      case "decimal":
      case "float": {
        const main = el("input", {
          class: "additional-fieldset default form-control form-control-sm",
          type: fieldType,
          name: `${valueName}[]`,
          value: (fieldValue[0] ?? "") || "",
        });
        const lower = el("input", {
          placeholder: "-∞",
          class: "additional-fieldset between form-control form-control-sm",
          type: fieldType,
          name: `${valueName}[]`,
          value: (fieldValue[1] ?? "") || "",
        });
        const upper = el("input", {
          placeholder: "∞",
          class: "additional-fieldset between form-control form-control-sm",
          type: fieldType,
          name: `${valueName}[]`,
          value: (fieldValue[2] ?? "") || "",
        });
        additional = [main, lower, upper];
        break;
      }
      default:
        control = el("input", {
          type: "text",
          class: "form-control form-control-sm",
          name: valueName,
          value: fieldValue,
        });
        break;
    }

    const containerId = `${fieldName}-${index}-filter-container`;
    document.getElementById(containerId)?.remove();

    const deleteButton = el(
      "button",
      { type: "button", class: "btn btn-info btn-sm delete" },
      icon("trash"),
      document.createTextNode(fieldLabel)
    );

    const content = el(
      "div",
      { id: containerId, class: "filter d-inline-block my-1" },
      deleteButton
    );
    content.append(" ");
    [].concat(control).forEach((node) => node && content.append(node));
    content.append(" ");
    [].concat(additional).forEach((node) => node && content.append(node));

    this.box.appendChild(content);
  }

  #buildOperator(operator, options) {
    if (operator instanceof Object) {
      const element = option(undefined, operator.label);
      const { label, ...attrs } = operator;
      for (const key in attrs) element.setAttribute(key, attrs[key]);
      return element;
    }
    switch (operator) {
      case "_discard":
        return option("_discard", "...");
      case "_separator":
        return option(null, "---------", { disabled: "disabled" });
      case "_present":
        return option("_present", I18n.t("is_present"));
      case "_blank":
        return option("_blank", I18n.t("is_blank"));
      case "_not_null":
        return option("_not_null", I18n.t("is_present"));
      case "_null":
        return option("_null", I18n.t("is_blank"));
      case "true":
        return option("true", I18n.t("true"));
      case "false":
        return option("false", I18n.t("false"));
      case "today":
        return option("today", I18n.t("today"));
      case "yesterday":
        return option("yesterday", I18n.t("yesterday"));
      case "this_week":
        return option("this_week", I18n.t("this_week"));
      case "last_week":
        return option("last_week", I18n.t("last_week"));
      case "like":
        return option("like", I18n.t("contains"), {
          "data-additional-fieldset": "additional-fieldset",
        });
      case "not_like":
        return option("not_like", I18n.t("does_not_contain"), {
          "data-additional-fieldset": "additional-fieldset",
        });
      case "is":
        return option("is", I18n.t("is_exactly"), {
          "data-additional-fieldset": "additional-fieldset",
        });
      case "starts_with":
        return option("starts_with", I18n.t("starts_with"), {
          "data-additional-fieldset": "additional-fieldset",
        });
      case "ends_with":
        return option("ends_with", I18n.t("ends_with"), {
          "data-additional-fieldset": "additional-fieldset",
        });
      case "default": {
        let label;
        switch (options.type) {
          case "date":
          case "datetime":
          case "timestamp":
            label = I18n.t("date");
            break;
          case "time":
            label = I18n.t("time");
            break;
          case "integer":
          case "decimal":
          case "float":
            label = I18n.t("number");
            break;
        }
        return option("default", label, {
          "data-additional-fieldset": "default",
        });
      }
      case "between":
        return option("between", I18n.t("between_and_"), {
          "data-additional-fieldset": "between",
        });
      default:
        return null;
    }
  }

  #switchSelect(toggle) {
    const select =
      toggle.parentElement.querySelector("select") ||
      toggle.previousElementSibling;
    const multiple = !select.hasAttribute("multiple");
    if (multiple) {
      select.setAttribute("multiple", "multiple");
      select.setAttribute("name", `${select.getAttribute("name")}[]`);
    } else {
      select.removeAttribute("multiple");
      select.setAttribute(
        "name",
        select.getAttribute("name").replace(/\[\]$/, "")
      );
    }
    this.#setValuelessOptionsHidden(select, multiple);
    toggle.querySelector("svg")?.replaceWith(icon(multiple ? "minus" : "plus"));
  }

  // Multi-select mode lists enum values only, so the "..."/presence operator
  // entries and the disabled separator hide. WebKit ignores display styling on
  // <option>, so hide with the `hidden` attribute and additionally disable the
  // value-carrying entries so they cannot be picked; the separator's own
  // disabled state is left alone (it doubles as its selector hook).
  #setValuelessOptionsHidden(select, hidden) {
    select
      .querySelectorAll("option[value^=_], option[disabled]")
      .forEach((o) => {
        o.hidden = hidden;
        if (o.getAttribute("value")) o.disabled = hidden;
      });
  }
}
