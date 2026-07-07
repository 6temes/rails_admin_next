// Document-level page interactions: global, delegated behaviors with no single
// host element (a select-all in the table head, the bulk-action menu in the
// navbar, sortable column headers, the export field pickers), so they stay
// plain delegated DOM listeners rather than per-element Stimulus controllers.
// Field/widget behaviors (datetime, file upload, rich text, the inline-edit
// modal) are Stimulus controllers instead.
//
// Registered once at import time — the document survives Turbo Drive navigation,
// so delegated listeners keep working across visits without re-binding.

// --- Loading indicator -------------------------------------------------------
document.addEventListener("turbo:click", () => {
  const loading = document.getElementById("loading");
  if (loading) loading.style.display = "";
});
document.addEventListener("turbo:before-render", () => {
  const loading = document.getElementById("loading");
  if (loading) loading.style.display = "none";
});

// --- Forms: preserve the clicked submit button ------------------------------
// Append a hidden input carrying the pressed button's name/value, and skip
// constraint validation for a [formnovalidate] button. The submit event's
// `submitter` is not reliably set for synthetic (script-driven) clicks, so the
// form body would otherwise lose which button was pressed (Save vs Cancel vs
// Save and edit) — and a Cancel could be blocked by an unrelated invalid field.
// Clicking clears out any hidden input left behind by an earlier click whose
// submit was blocked by native validation, so a stale button param can't ride
// along on the next, different submit.
document.addEventListener("click", (event) => {
  const button = event.target.closest('button[name][type="submit"]');
  if (!button) return;
  const form = button.form || button.closest("form");
  if (!form) return;
  form
    .querySelectorAll("input[data-submit-button-param]")
    .forEach((input) => input.remove());
  const hidden = document.createElement("input");
  hidden.type = "hidden";
  hidden.name = button.name;
  hidden.value = button.value;
  hidden.dataset.submitButtonParam = "true";
  form.appendChild(hidden);
  if (button.hasAttribute("formnovalidate"))
    form.setAttribute("novalidate", "true");
});

// --- Index list: select-all bulk checkboxes ----------------------------------
document.addEventListener("change", (event) => {
  if (!event.target.matches("#list input.toggle")) return;
  document
    .querySelectorAll("#list [name='bulk_ids[]']")
    .forEach((checkbox) => (checkbox.checked = event.target.checked));
});

// --- Index list: sortable column headers -------------------------------------
document.addEventListener("click", (event) => {
  const header = event.target.closest("th.header");
  if (!header) return;
  event.preventDefault();
  if (header.dataset.href) window.Turbo.visit(header.dataset.href);
});

// --- Index list: bulk-action menu links --------------------------------------
document.addEventListener("click", (event) => {
  const link = event.target.closest(".bulk-link");
  if (!link) return;
  event.preventDefault();
  const action = document.getElementById("bulk_action");
  if (action) action.value = link.dataset.action;
  // Native submit (full navigation): the bulk action renders its confirmation
  // page with a 200, which Turbo's form handling would reject as "must
  // redirect".
  document.getElementById("bulk_form")?.submit();
});

// --- Index list: reset filters -----------------------------------------------
document.addEventListener("click", (event) => {
  const button = event.target.closest("#remove_filter");
  if (!button) return;
  event.preventDefault();
  // Emptying the box is the whole state change: the hr.filters_box divider
  // derives its visibility from the .filter rows via :has() CSS (skin.css).
  document.getElementById("filters_box")?.replaceChildren();
  const form = button.closest("form");
  const search = button.parentNode.querySelector("input[type='search']");
  if (search) search.value = "";
  form?.requestSubmit();
});

// --- Export: select-all / reverse-selection ----------------------------------
document.addEventListener("change", (event) => {
  if (!event.target.matches("#fields_to_export #check_all")) return;
  document
    .querySelectorAll("#fields_to_export label input")
    .forEach((input) => (input.checked = event.target.checked));
});
document.addEventListener("click", (event) => {
  const card = event.target.closest("#fields_to_export .reverse-selection");
  if (!card) return;
  card
    .closest(".control-group")
    .querySelectorAll(".controls input")
    .forEach((input) => input.click());
});

// --- File upload: inline image preview + delete toggle -----------------------
function isImage(filename) {
  return ["gif", "png", "jpg", "jpeg", "bmp"].includes(
    filename.split(".").pop().toLowerCase()
  );
}

// Single upload: replace/insert one preview image on change.
document.addEventListener("change", (event) => {
  const input = event.target;
  if (!input.matches("[data-fileupload]")) return;
  const parent = input.parentNode;
  let preview = parent.querySelector(":scope > img.preview");
  if (!preview) {
    preview = document.createElement("img");
    preview.className = "preview img-thumbnail";
    parent.prepend(preview);
    parent
      .querySelectorAll("img:not(.preview)")
      .forEach((img) => (img.style.display = "none"));
  }
  if (input.files && input.files[0] && isImage(input.value)) {
    const file = input.files[0];
    const reader = new FileReader();
    reader.onload = (e) => {
      if (input.files[0] === file) preview.src = e.target.result;
    };
    reader.readAsDataURL(file);
    preview.style.display = "";
  } else {
    preview.style.display = "none";
  }
});

// Multiple upload: render one preview per selected image.
document.addEventListener("change", (event) => {
  const input = event.target;
  if (!input.matches("[data-multiple-fileupload]")) return;
  const parent = input.parentNode;
  parent.querySelectorAll(":scope > .preview").forEach((node) => node.remove());
  Array.from(input.files).forEach((file) => {
    if (!isImage(file.name)) return;
    const image = document.createElement("img");
    image.className = "preview img-thumbnail";
    const reader = new FileReader();
    reader.onload = (e) => (image.src = e.target.result);
    reader.readAsDataURL(file);
    const wrapper = document.createElement("div");
    wrapper.className = "preview";
    wrapper.appendChild(image);
    parent.appendChild(wrapper);
  });
});

// "Delete file" button: toggle the hidden delete/keep checkbox and hide the row.
document.addEventListener("click", (event) => {
  const button = event.target.closest(".btn-remove-image");
  if (!button) return;
  event.preventDefault();
  button.parentNode.querySelector("input[type=checkbox]")?.click();
  const toggle =
    button.closest(".toggle") || button.parentNode.querySelector(".toggle");
  if (toggle)
    toggle.style.display = toggle.style.display === "none" ? "" : "none";
  button.classList.toggle("btn-danger");
  button.classList.toggle("btn-info");
});

// --- Sidebar groups: persist collapsed <details> across Turbo visits ----------
// The sidebar disclosure groups are native <details data-collapse-key> elements
// the server always renders open. Before Turbo swaps bodies, copy each keyed
// group's collapsed state onto its counterpart in the new body, so any number
// of collapsed groups survive navigation regardless of group order.
document.addEventListener("turbo:before-render", (event) => {
  document
    .querySelectorAll("details[data-collapse-key]:not([open])")
    .forEach((details) => {
      event.detail.newBody
        .querySelector(
          `details[data-collapse-key="${details.dataset.collapseKey}"]`
        )
        ?.removeAttribute("open");
    });
});

// --- Form field groups: collapse on legend click -----------------------------
function siblingControlGroups(legend) {
  return Array.from(legend.parentNode.children).filter(
    (node) => node !== legend && node.classList.contains("control-group")
  );
}

document.addEventListener("click", (event) => {
  const legend = event.target.closest("form legend");
  if (!legend) return;
  // A single chevron-down SVG; the `collapsed` class rotates it to point right.
  const chevron = legend.querySelector('svg[data-icon="collapse"]');
  if (!chevron) return;
  const collapsing = !chevron.classList.contains("collapsed");
  siblingControlGroups(legend).forEach(
    (group) => (group.style.display = collapsing ? "none" : "")
  );
  chevron.classList.toggle("collapsed");
});

// Groups whose legend renders collapsed start hidden.
document.addEventListener("rails_admin.dom_ready", () => {
  document.querySelectorAll("form.main legend").forEach((legend) => {
    if (legend.querySelector('svg[data-icon="collapse"].collapsed')) {
      siblingControlGroups(legend).forEach(
        (group) => (group.style.display = "none")
      );
    }
  });
});
