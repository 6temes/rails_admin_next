// Inline-SVG icons for client-rendered widgets (filter box, filtering select and
// multiselect). Mirrors the server-side RailsAdminNext::Icons helper
// (lib/rails_admin_next/icons.rb): the same Font Awesome Free 6.1.1 (solid) glyph
// data and the same data-icon/class output, so JS- and server-rendered icons match.
// Only the glyphs drawn at runtime live here; the full set is owned by the Ruby side.

const SVG_NS = "http://www.w3.org/2000/svg";

const GLYPHS = {
  delete: {
    viewBox: "0 0 320 512",
    path: "M310.6 361.4c12.5 12.5 12.5 32.75 0 45.25C304.4 412.9 296.2 416 288 416s-16.38-3.125-22.62-9.375L160 301.3L54.63 406.6C48.38 412.9 40.19 416 32 416S15.63 412.9 9.375 406.6c-12.5-12.5-12.5-32.75 0-45.25l105.4-105.4L9.375 150.6c-12.5-12.5-12.5-32.75 0-45.25s32.75-12.5 45.25 0L160 210.8l105.4-105.4c12.5-12.5 32.75-12.5 45.25 0s12.5 32.75 0 45.25l-105.4 105.4L310.6 361.4z",
  },
  minus: {
    viewBox: "0 0 448 512",
    path: "M400 288h-352c-17.69 0-32-14.32-32-32.01s14.31-31.99 32-31.99h352c17.69 0 32 14.3 32 31.99S417.7 288 400 288z",
  },
  move_down: {
    viewBox: "0 0 512 512",
    path: "M256 0C114.6 0 0 114.6 0 256c0 141.4 114.6 256 256 256s256-114.6 256-256C512 114.6 397.4 0 256 0zM390.6 246.6l-112 112C272.4 364.9 264.2 368 256 368s-16.38-3.125-22.62-9.375l-112-112c-12.5-12.5-12.5-32.75 0-45.25s32.75-12.5 45.25 0L256 290.8l89.38-89.38c12.5-12.5 32.75-12.5 45.25 0S403.1 234.1 390.6 246.6z",
  },
  move_left: {
    viewBox: "0 0 512 512",
    path: "M256 0C114.6 0 0 114.6 0 256c0 141.4 114.6 256 256 256s256-114.6 256-256C512 114.6 397.4 0 256 0zM310.6 345.4c12.5 12.5 12.5 32.75 0 45.25s-32.75 12.5-45.25 0l-112-112C147.1 272.4 144 264.2 144 256s3.125-16.38 9.375-22.62l112-112c12.5-12.5 32.75-12.5 45.25 0s12.5 32.75 0 45.25L221.3 256L310.6 345.4z",
  },
  move_right: {
    viewBox: "0 0 512 512",
    path: "M256 0C114.6 0 0 114.6 0 256c0 141.4 114.6 256 256 256s256-114.6 256-256C512 114.6 397.4 0 256 0zM358.6 278.6l-112 112c-12.5 12.5-32.75 12.5-45.25 0s-12.5-32.75 0-45.25L290.8 256L201.4 166.6c-12.5-12.5-12.5-32.75 0-45.25s32.75-12.5 45.25 0l112 112C364.9 239.6 368 247.8 368 256S364.9 272.4 358.6 278.6z",
  },
  move_up: {
    viewBox: "0 0 512 512",
    path: "M256 0C114.6 0 0 114.6 0 256c0 141.4 114.6 256 256 256s256-114.6 256-256C512 114.6 397.4 0 256 0zM390.6 310.6c-12.5 12.5-32.75 12.5-45.25 0L256 221.3L166.6 310.6c-12.5 12.5-32.75 12.5-45.25 0s-12.5-32.75 0-45.25l112-112C239.6 147.1 247.8 144 256 144s16.38 3.125 22.62 9.375l112 112C403.1 277.9 403.1 298.1 390.6 310.6z",
  },
  new: {
    viewBox: "0 0 448 512",
    path: "M432 256c0 17.69-14.33 32.01-32 32.01H256v144c0 17.69-14.33 31.99-32 31.99s-32-14.3-32-31.99v-144H48c-17.67 0-32-14.32-32-32.01s14.33-31.99 32-31.99H192v-144c0-17.69 14.33-32.01 32-32.01s32 14.32 32 32.01v144h144C417.7 224 432 238.3 432 256z",
  },
  trash: {
    viewBox: "0 0 448 512",
    path: "M135.2 17.69C140.6 6.848 151.7 0 163.8 0H284.2C296.3 0 307.4 6.848 312.8 17.69L320 32H416C433.7 32 448 46.33 448 64C448 81.67 433.7 96 416 96H32C14.33 96 0 81.67 0 64C0 46.33 14.33 32 32 32H128L135.2 17.69zM394.8 466.1C393.2 492.3 372.3 512 346.9 512H101.1C75.75 512 54.77 492.3 53.19 466.1L31.1 128H416L394.8 466.1z",
  },
};

// Semantic synonyms => canonical glyph name, mirroring the Ruby ALIASES subset.
const ALIASES = { cancel: "delete", plus: "new", times: "delete" };

// Build an inline <svg> element for a logical icon name (see GLYPHS), or null if
// the name is unknown. Output mirrors the server-side rails_admin_icon helper.
export function icon(name, { className = "" } = {}) {
  const key = GLYPHS[name] ? name : ALIASES[name];
  const glyph = key && GLYPHS[key];
  if (!glyph) return null;

  const svg = document.createElementNS(SVG_NS, "svg");
  svg.setAttribute("viewBox", glyph.viewBox);
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");
  svg.setAttribute("data-icon", key);
  svg.setAttribute("class", `rails-admin-icon ${className}`.trim());
  const path = document.createElementNS(SVG_NS, "path");
  path.setAttribute("d", glyph.path);
  svg.appendChild(path);
  return svg;
}
