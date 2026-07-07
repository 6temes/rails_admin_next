// Shared by the filtering-select and filtering-multiselect Stimulus controllers:
// createQuery/scopeBy logic for building a (possibly scoped) remote query.

// Builds the remote query for a (possibly dynamically-scoped) association select.
// `scopeBy` maps a sibling field name -> the query key it constrains; the sibling's
// current value scopes the candidate list.
export function createScopedQuery(scopeBy, term) {
  if (!scopeBy || Object.keys(scopeBy).length === 0) {
    return { query: term };
  }

  const f = {};
  for (const field in scopeBy) {
    const targetField = scopeBy[field];
    const sibling = document.querySelector(`[name$="[${field}]"]`);
    const value = sibling ? sibling.value : "";
    (f[targetField] ||= []).push(
      value ? { o: "is", v: value } : { o: "_blank" }
    );
  }
  return { query: term, f };
}

// Rails-style nested query string: { f: { team: [{ o: "is", v: 5 }] } } ->
// "f[team][0][o]=is&f[team][0][v]=5", matching the bracket notation Rails'
// param parser expects for nested params.
export function toQueryString(obj, prefix) {
  const parts = [];
  for (const key in obj) {
    const value = obj[key];
    const name = prefix ? `${prefix}[${key}]` : key;
    if (value !== null && value !== undefined && typeof value === "object") {
      const nested = toQueryString(value, name);
      if (nested) parts.push(nested);
    } else {
      parts.push(
        `${encodeURIComponent(name)}=${encodeURIComponent(value ?? "")}`
      );
    }
  }
  return parts.join("&");
}

// Escape a user-typed term for use in a case-insensitive RegExp.
export function escapeRegex(value) {
  return String(value).replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, "\\$&");
}

// Shared CSRF-token + JSON-fetch boilerplate for the filtering-select and
// filtering-multiselect remote (xhr) query paths. Callers keep their own
// requestId/AbortController bookkeeping and pass the controller's `signal`.
export function fetchJson(url, { signal } = {}) {
  const token = document.querySelector('meta[name="csrf-token"]')?.content;
  return fetch(url, {
    headers: {
      Accept: "application/json",
      ...(token ? { "X-CSRF-Token": token } : {}),
    },
    credentials: "same-origin",
    signal,
  }).then((response) => {
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  });
}
