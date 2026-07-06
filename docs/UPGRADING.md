# Upgrading from rails_admin to rails_admin_next

`rails_admin_next` is the modernized fork of `rails_admin`: Rails 8.1 / Ruby 4.0 floor,
ActiveRecord only, an importmap + Propshaft asset pipeline, a Stimulus + Turbo
frontend (no jQuery, jQuery-UI, Bootstrap JS, or `@rails/ujs`), vanilla CSS with a
latest-Chrome/Safari browser floor, and a hardened security posture. This guide covers
the one-time changes a host app needs.

The Ruby namespace is renamed **`RailsAdmin` → `RailsAdminNext`** (and `rails_admin` →
`rails_admin_next`), so your initializer, engine mount, model macros, and route helpers
need a mechanical rename. The **authorization contract is deliberately unchanged** — the
`:access, :rails_admin` subject and the `admin.*` I18n namespace stay exactly as they were,
so your CanCanCan abilities, Pundit policies, and translations need no edits.

## 1. Gemfile

Replace the upstream `rails_admin` gem with the fork (distributed via `git:`):

```ruby
# Gemfile
gem 'rails_admin_next', git: 'https://github.com/6temes/rails_admin_next'
```

Remove the old `gem 'rails_admin'` line, then `bundle install`.

## 2. Application code — rename the namespace

Rename `RailsAdmin` → `RailsAdminNext` and `rails_admin` → `rails_admin_next` in your
initializer, mount, per-model blocks, and route-helper calls:

```ruby
# config/initializers/rails_admin_next.rb  (renamed from config/initializers/rails_admin.rb)
RailsAdminNext.config do |config|
  config.model User do
    # …
  end
end

# config/routes.rb
mount RailsAdminNext::Engine => '/admin', as: 'rails_admin_next'

# per-model blocks
class Team < ApplicationRecord
  rails_admin_next do
    field :name
  end
end

# route helpers
rails_admin_next.dashboard_path
rails_admin_next.edit_path(model_name: 'team', id: team.id)
```

Running `rails g rails_admin_next:install` writes the new initializer and mount for you.

## 3. Icons (`link_icon` / `navigation_icon`)

Font Awesome is **no longer shipped** (no icon font, no `font-awesome.css`). Icons now
render as inline SVG, and the icon options take a **logical icon name** (a Symbol or
String) instead of a Font Awesome class string:

```ruby
# Before
RailsAdminNext.config do |config|
  config.model Team do
    navigation_icon 'fas fa-trophy'
  end
  config.actions do
    # …
    my_custom_action { link_icon 'fas fa-rocket' }
  end
end

# After
RailsAdminNext.config do |config|
  config.model Team do
    navigation_icon :list      # a logical name (see the list below)
  end
  config.actions do
    my_custom_action { link_icon :show_in_app }
  end
end
```

Available logical names (see `RailsAdminNext::Icons::GLYPHS`):

`:dashboard` (alias `:home`), `:list`, `:show` (alias `:info`), `:new` (alias `:add`/`:plus`),
`:edit` (alias `:pencil`), `:delete` (aliases `:cancel`/`:times`), `:export`,
`:history` (alias `:book`), `:show_in_app` (alias `:eye`), `:bulk_delete` (alias `:question`),
`:collapse`, `:expand`, `:calendar`, `:check`, `:minus`, `:refresh` (alias `:sync`),
`:trash`, `:move_right`, `:move_left`, `:move_up`, `:move_down`.

**Legacy Font Awesome strings still given to `link_icon`/`navigation_icon` are handled
gracefully**: the glyph is best-effort mapped to the nearest logical name and a deprecation
warning is emitted (`RailsAdminNext.deprecator`); a value that can't be mapped renders no
icon rather than raising. Migrate to logical names to silence the warning. If you relied on
Font Awesome classes elsewhere in your own admin views, vendor Font Awesome yourself — the
engine no longer provides it.

## Authorization (no change needed)

The authorization contract is held stable — **do not touch your abilities or policies**:

- The access subject is `:rails_admin`.
- Every action's authorization key (`:dashboard`, `:index`, `:show`, `:new`, `:edit`,
  `:export`, `:destroy`, `:history`, `:show_in_app`) is unchanged.

```ruby
# This CanCanCan ability keeps working unchanged:
can :access, :rails_admin
```

The access subject is deliberately frozen and locked by a spec in the gem — a renamed
subject can fail *open* (a `cannot` rule that no longer matches silently grants access).

## Asset prerequisites

RailsAdminNext ships its frontend over **importmap + Propshaft** only — there is no
build step and no Sprockets/Webpacker/Webpack/Vite support. The host app must use:

- **Propshaft** (`config.assets.*` via `propshaft`), and
- **importmap-rails**.

Optional:

- **Thruster** in front of the app for edge caching of the fingerprinted assets.
- Set `config.assets.integrity_hash_algorithm` if you want Subresource Integrity on the
  engine's self-hosted modules (off by default; same-origin hosting makes SRI low-value).

## Browser support

The frontend targets the **latest stable Chrome and Safari only**. This fork is an internal
tool for teams that control their admin users' browsers; the old "Baseline 2023 /
Firefox ≥ 111" contract is retired deliberately, and no legacy-browser fallbacks ship. The
engine's CSS and JS assume `:has()`, `<dialog>`, popovers, CSS nesting, `oklch()`,
`color-mix()`, `light-dark()`, `@starting-style`, and CSS anchor positioning.

Two features are newer still: `closedby="any"` (backdrop light-dismissal of the inline-edit
dialog) needs Chromium 134+ / Safari 26, and CSS anchor positioning needs Chromium 128+ /
Safari 26 (dropdown menus are positioned by anchor CSS alone — no JS fallback ships).
`field-sizing: content` (auto-growing textareas) is a Chromium-only enhancement — other
browsers keep fixed-height textareas.

## Styling: cascade layers and design tokens

Bootstrap's SCSS is gone. Styling is hand-maintained vanilla CSS delivered through three
cascade layers, declared in `rails_admin.css` (the layer names are a documented contract):

- `ra.tokens` — design tokens (CSS custom properties)
- `ra.framework` — the trimmed ex-Bootstrap component CSS
- `ra.skin` — the engine's own widgets, icons, and admin skin

Because all engine CSS is layered, **any unlayered host rule beats it** — a plain rule in
your own stylesheet overrides the admin without `!important` or specificity games:

```css
/* host stylesheet — no layer, so it wins over everything the engine ships */
.badge {
  border-radius: 7px;
}
```

### Supported override tokens (public API)

Hosts may override these tokens (unlayered, e.g. `:root { --ra-primary: #663399; }`) and
every derived color — button hover/active states, focus rings, alert tints, table tints,
links — follows automatically:

| Token | Role |
| --- | --- |
| `--ra-primary`, `--ra-secondary`, `--ra-success`, `--ra-info`, `--ra-warning`, `--ra-danger`, `--ra-light`, `--ra-dark` | brand and status colors |
| `--ra-body-bg`, `--ra-body-color` | body surface and text |
| `--ra-link-color` | link color (defaults to a tint of `--ra-primary`) |

A single-color override applies to both light and dark schemes; hosts that want a tuned dark
mode should override with their own pair:

```css
:root {
  --ra-primary: light-dark(#663399, #a97fd6);
}
```

**Every other `--ra-*` name is internal and may change without notice.**

### Dark mode and the `color_scheme` knob

The admin now follows the OS color-scheme preference automatically: every color token is a
`light-dark()` pair, resolved against a `<meta name="color-scheme">` the layout renders from
the new config knob:

```ruby
RailsAdminNext.config do |config|
  config.color_scheme = :auto # default; :light or :dark pins the scheme
end
```

Pin `:light` to keep the old always-light rendering. Two deliberate exceptions: the navbar is
scheme-locked (`navbar_css_classes` express host intent — `navbar-dark bg-primary` stays a
dark navbar under both schemes), and the Trix (ActionText) editor stays light-only for now.

### Token mapping: `--bs-*` → `--ra-*`

The Bootstrap `--bs-*` custom properties are gone. Renamed with the same meaning — read or
override the new name:

| Old | New | Note |
| --- | --- | --- |
| `--bs-body-bg` | `--ra-body-bg` | |
| `--bs-body-color` | `--ra-body-color` | |
| `--bs-body-font-family` | `--ra-body-font-family` | |
| `--bs-body-font-size` | `--ra-body-font-size` | |
| `--bs-body-font-weight` | `--ra-body-font-weight` | |
| `--bs-body-line-height` | `--ra-body-line-height` | |
| `--bs-body-text-align` | `--ra-body-text-align` | still undeclared by default; set it to opt in, exactly like Bootstrap's knob |
| `--bs-breadcrumb-divider` | `--ra-breadcrumb-divider` | |
| `--bs-font-monospace` | `--ra-font-monospace` | |
| `--bs-font-sans-serif` | `--ra-font-sans-serif` | |
| `--bs-gradient` | `--ra-gradient` | |
| `--bs-gutter-x` / `--bs-gutter-y` | `--ra-gutter-x` / `--ra-gutter-y` | grid-scoped |
| `--bs-table-bg` | `--ra-table-bg` | table-scoped; likewise `-accent-bg`, `-striped-bg`, `-striped-color`, `-active-bg`, `-active-color`, `-hover-bg`, `-hover-color` |

Renamed with a value-space change (number → percentage):

| Old | New |
| --- | --- |
| `--bs-bg-opacity: 0.5` | `--ra-bg-opacity: 50%` |
| `--bs-text-opacity: 0.5` | `--ra-text-opacity: 50%` |

Previously declared but consumed by nothing — now live semantic tokens (overriding the
`--bs-*` name never did anything; the `--ra-*` name works): `--bs-primary` →
`--ra-primary`, `--bs-secondary` → `--ra-secondary`, `--bs-success` → `--ra-success`,
`--bs-info` → `--ra-info`, `--bs-warning` → `--ra-warning`, `--bs-danger` → `--ra-danger`,
`--bs-light` → `--ra-light`, `--bs-dark` → `--ra-dark`.

Removed — replaced by derivation (never override these; override the base token instead):
the whole `-rgb` family (`--bs-primary-rgb` … `--bs-dark-rgb`, `--bs-white-rgb`,
`--bs-black-rgb`, `--bs-body-color-rgb`, `--bs-body-bg-rgb`) is gone; utilities now derive
translucency via `color-mix(in srgb, var(--ra-*) <pct>, transparent)`.

Removed without replacement (declared but never consumed): the raw color ladder
(`--bs-blue`, `--bs-indigo`, `--bs-purple`, `--bs-pink`, `--bs-red`, `--bs-orange`,
`--bs-yellow`, `--bs-green`, `--bs-teal`, `--bs-cyan` — the code-pink role of `--bs-pink`
lives on as the internal `--ra-code-color`), `--bs-white`, `--bs-gray`, `--bs-gray-dark`,
`--bs-gray-100` … `--bs-gray-900` (the grays the CSS actually uses exist as internal
`--ra-gray-*` tokens), and `--bs-position` (set by `.dropdown-menu-end` for Bootstrap's
dropdown JS, which this engine does not ship).

### Removed component CSS

The flattened Bootstrap CSS was trimmed to what the engine actually renders. These component
families were deleted as unreachable:

| Removed family | If you relied on it |
| --- | --- |
| Carousel | No engine view renders one; ship your own carousel CSS/JS in custom actions. |
| Tooltip (`.tooltip`, `.bs-tooltip-*`) | Bootstrap tooltips needed Bootstrap JS, which the engine does not ship; use the native `title` attribute or your own library. |
| Popover component (`.popover`, `.bs-popover-*`) | Same as tooltips. (The native `popover` *attribute* is what the engine now uses for its dropdown menus.) |
| Toasts | Engine flash messages render as alerts; `alert-*` stays supported. |
| Offcanvas | Never emitted by engine views. |
| Accordion | Sidebar groups are native `<details>`/`<summary>` now. |
| Spinners (`.spinner-border`, `.spinner-grow`) | The engine's loading indicator is the `#loading` badge. |
| Placeholders (loading skeletons) | Never emitted by engine views. |
| Floating labels (`.form-floating`) | Engine forms use stacked labels. |
| `.form-range` | No engine form renders a range input. |
| Form validation (`.is-valid` / `.is-invalid` / `*-feedback` / `*-tooltip`) | Engine forms render server-side errors through their own `.error` + `.help-inline.text-danger` markup, which is kept. |
| `.form-check` / `.form-switch` wrapper styling | Checkboxes/radios are native, tinted via `accent-color`; `.form-check-input` itself is still styled. |
| jQuery-UI chrome | jQuery-UI is gone. |
| wysihtml5 editor chrome | The editor was dropped; use ActionText/Trix. |
| `.collapsing` | Bootstrap JS's collapse-transition class; sidebar collapse is a native `<details>`. |
| `[data-bs-popper]` rules | Popper.js is not shipped. |
| `.dropup` / `.dropend` / `.dropstart` | Engine menus only drop down (and flip above the toggle automatically near the viewport edge). |
| Responsive tiers `sm` / `lg` / `xl` / `xxl` | The `.col-sm-*` grid columns engine forms emit survive; the responsive display/spacing/text utilities and `container-*` tiers are gone (a couple of `md` utilities remain). |
| Print utilities (`.d-print-*`) | Gone; add your own print CSS if you print admin pages. |

### The styled vocabulary (keep-list)

The stylesheet keeps a deliberate keep-list even where no engine view currently emits the
class: vocabularies that are host-facing configuration API remain styled and supported —

- `.navbar-light` / `.navbar-dark` — the `navbar_css_classes` value space,
- `alert-*` — the `flash_alert_class` value space,
- `bg-*` utilities — badges, indicators, and the host navbar,
- `.badge` colors,
- `table-*` contextual rows — `row_css_class` conventions.

Class names the stylesheet does not style are out of contract and may stay unstyled.

## Markup changes

Three widgets moved from Bootstrap markup to native platform primitives. Hand-rolled host CSS
or JS that targeted the old DOM needs updating — `.modal.fade`, `.dropdown .show`, and the
sidebar's `.collapse` no longer appear:

| Widget | Was | Now |
| --- | --- | --- |
| Inline-edit modal | `.modal.fade` + `.modal-dialog` divs | native `<dialog id="modal" closedby="any">` |
| Dropdown menus (filters, bulk actions) | `<a role="button">` toggles + `.dropdown .show` | `<button popovertarget>` toggles + `popover="auto"` menus, positioned with CSS anchor positioning |
| Sidebar navigation groups | `.collapse` + Bootstrap collapse classes | native `<details>`/`<summary>` disclosures |

## Dropped support

These are intentionally gone — migrate off them before upgrading:

- **Mongoid** — RailsAdminNext is ActiveRecord only.
- **Sprockets / Webpacker / Webpack / Vite** — importmap + Propshaft only.
- **Standalone WYSIWYG/code editor field types** (`bootstrap-wysihtml5`, `froala`, and the
  cdnjs-backed `:ck_editor` / `:code_mirror` / `:simple_mde`) — they loaded JS/CSS from cdnjs.
  Migrate those fields to `:action_text` (self-hosted Trix rich text) or a plain `:text` textarea
  instead. The engine now has **zero external CDN** usage, default and opt-in.
- **Non-ActiveStorage attachment libraries** (CarrierWave, Paperclip, Shrine, Dragonfly,
  Refile) — RailsAdminNext detects **ActiveStorage** (and ActionText/Trix) attachments only.
  Migrate file/image columns to ActiveStorage before upgrading. Image variants are processed
  with **libvips** via `image_processing` + `ruby-vips` (set
  `config.active_storage.variant_processor = :vips`); install the libvips system library
  (`brew install vips` / `apt-get install libvips-dev`) — ImageMagick is no longer required.
- **Configurable app branding (`main_app_name`)** — the navbar brand and page `<title>` are
  hardcoded to "Rails AdminNext"; the config option is gone. Fork
  `app/views/layouts/rails_admin_next/_navigation.html.erb` and `content.html.erb` in your
  host app if you need custom branding.

## History / audit table

The gem owns **no** history table. Auditing remains host/PaperTrail territory, so there is
no gem migration to run — your existing `rails_admin_histories` table (if any) is unaffected.
