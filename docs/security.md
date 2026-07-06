# Security posture

The admin is a privileged surface. This engine ships the request-forgery, framing, and
destructive-action controls itself; a few things are left for the host to opt into.

## Always on

- **CSRF.** `protect_from_forgery(with: :exception)` is hardcoded. A non-GET request without a
  valid token is rejected (`ActionController::InvalidAuthenticityToken` → HTTP 422). There is no
  host-configurable forgery option to weaken it.
- **Clickjacking.** Every admin response carries `X-Frame-Options: SAMEORIGIN`.
- **Export.** The CSV/JSON/XML data stream requires a non-GET, CSRF-protected request; `GET` only
  renders the export form, so the table can't be exfiltrated via a crafted link.
- **Destructive actions.** `delete` and `bulk_delete` render a confirmation page and additionally
  carry `data-turbo-confirm` on the destructive submit (Turbo's confirmation, not `@rails/ujs`).
- **Mass assignment.** Submitted attributes are sliced to the model config's `visible_fields`
  before `permit!`, at the top level and at every nested depth, regardless of the submitted
  nested-attributes cardinality (hash or array).

## Content Security Policy (opt-in)

The engine enforces **no** CSP by default. When you opt in, it applies the policy per-request to
admin responses only (never to the host app) and threads a per-request nonce onto every inline tag
it emits (the importmap JSON, the import entry point, the index column-width `<style>`), so a
`:self` + nonce policy does not block the admin's own pinned modules.

```ruby
# config/initializers/rails_admin_next.rb
RailsAdminNext.config do |config|
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline # see note below
    policy.img_src     :self, :data
    policy.font_src    :self
    policy.connect_src :self
  end
end
```

Tune it without breaking pages first by reporting only:

```ruby
RailsAdminNext.config do |config|
  config.content_security_policy(report_only: true) do |policy|
    policy.default_src :self
  end
end
```

> **Note on `style-src`.** The admin still renders five inline `style="…"` attributes, which a CSP
> nonce cannot cover (nonces apply to `<script>`/`<style>` elements, not style attributes), so a
> `style-src` directive needs `:unsafe_inline` for now. The engine's own `<style>` element (the
> index column-width block) is nonced. The remaining attributes:
>
> - the `#loading` badge's positioning in the layout, and the delete-notice `<li>` spacing —
>   static values, removable by moving them into the stylesheet;
> - the file-upload delete toggle's initial `display:none` — conditional initial state, removable
>   by switching to the `hidden` attribute;
> - the dashboard's `.progress` margin (static) and each progress bar's `width: N%` (a per-row
>   dynamic value — the one that genuinely resists removal; it would need the nonced-`<style>`
>   route or a native `<progress>` element).
>
> Once those five are reauthored, `:unsafe_inline` can be dropped.
