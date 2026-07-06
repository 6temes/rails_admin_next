// Minimal DOM-builder shared by the filter/select Stimulus controllers
// (filter_box, filtering_select, filtering_multiselect). Boolean `true`
// in `attrs` renders a bare HTML boolean attribute (setAttribute(key, key),
// e.g. { multiple: true } -> multiple="multiple"); `false`/`null`/`undefined`
// skip the attribute entirely; anything else is stringified via setAttribute.
// `null`/`undefined` children are skipped so callers can splice in
// conditional content inline.
export function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === true) node.setAttribute(key, key);
    else if (value != null && value !== false) node.setAttribute(key, value);
  }
  for (const child of children) {
    if (child == null) continue;
    node.append(child);
  }
  return node;
}
