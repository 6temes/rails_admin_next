---
name: rails-admin-next
description: Configure or extend the rails_admin_next admin in a host Rails app (models, fields, custom actions and field types, CanCanCan/Pundit authorization, PaperTrail history, theming, CSP). Use instead of upstream RailsAdmin knowledge, which is wrong for this fork.
---

# rails_admin_next

rails_admin_next is a hard fork of RailsAdmin: ActiveRecord only, Rails 8.1, importmap + Propshaft, Turbo + Stimulus, no build step. Most of the per-model DSL is unchanged from upstream, but the namespace, the asset stack and the frontend are not. Code written from upstream RailsAdmin memory is usually wrong here.

## Read the installed gem first

Every `<gem>/` path below is relative to the directory this prints:

```bash
bundle info --path rails_admin_next
```

Read the version the app actually bundles before answering:

- `<gem>/docs/UPGRADING.md` lists every difference from upstream RailsAdmin.
- `<gem>/docs/security.md` covers what the engine enforces and what the host opts into.
- `<gem>/docs/upstream-parity.md` has a "Standing divergences" section on behavior that deliberately differs from upstream patches.
- `<gem>/lib/rails_admin_next/config/` is the DSL itself. When this skill and the source disagree, the source wins.

The upstream RailsAdmin wiki is still accurate for model, group and field options that the fork leaves unchanged. Check it against the source above before relying on it.

## Naming: what was renamed, what was not

Renamed (write the new form):

- Ruby namespace `RailsAdminNext`, configured with `RailsAdminNext.config do |config| ... end` in config/initializers/rails_admin_next.rb.
- Mount: `mount RailsAdminNext::Engine => "/admin", as: "rails_admin_next"`. Keep the `rails_admin_next` alias, because the engine's views call that route proxy.
- Per-model macro `rails_admin_next do ... end`.
- Route helpers `rails_admin_next.dashboard_path`, `rails_admin_next_url`, and `bindings[:view].rails_admin_next` inside field blocks.

Not renamed (leave as is):

- The authorization subject is still `:rails_admin`. CanCanCan abilities grant `can :access, :rails_admin`. Never rewrite it to `:rails_admin_next`, which fails authorization.
- Action authorization keys (`:dashboard`, `:index`, `:show`, `:new`, `:edit`, `:export`, `:destroy`, `:history`, `:show_in_app`).
- The `admin.*` I18n namespace.

`bin/rails g rails_admin_next:install` writes the initializer and the mount.

## Models, sections and fields

Configure a model either inline with the `rails_admin_next do ... end` macro or in the initializer with `config.model "Team" do ... end`. Both take the upstream DSL: `list`, `show`, `edit`, `create`, `update`, `export`, `nested` and `modal` sections, plus `field`, `configure`, `exclude_fields`, `group` and `navigation_icon`. Global options live on `config`, for example `included_models`, `excluded_models`, `default_items_per_page` and `label_methods`.

Field types live in `<gem>/lib/rails_admin_next/config/fields/types/`. A custom type subclasses one of them and registers with `RailsAdminNext::Config::Fields::Types.register(MyType)`. Register it under a name of your own, or the registration replaces the built-in type.

Read the "Required `belongs_to` associations" and "Nested forms hide the link back to the parent" sections of `<gem>/docs/UPGRADING.md` before changing association fields. Both behave differently from upstream.

## Actions

Pick and order actions in the initializer:

```ruby
RailsAdminNext.config do |config|
  config.actions do
    dashboard
    index
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app
  end
end
```

A custom action subclasses `RailsAdminNext::Config::Actions::Base`, registers with `RailsAdminNext::Config::Actions.register(self)`, and then appears by name inside `config.actions`. Its options (`member`, `collection`, `http_methods`, `controller`, `link_icon`, `visible?`, `authorization_key`, `template_name` and the rest) are declared in `<gem>/lib/rails_admin_next/config/actions/base.rb`. `<gem>/lib/rails_admin_next/config/actions/show_in_app.rb` is a short example. The action renders the host view app/views/rails_admin_next/main/<template_name>.html.erb.

Icons take logical names, never Font Awesome classes: `link_icon :show_in_app` or `navigation_icon :list`. The list is in the "Icons" section of `<gem>/docs/UPGRADING.md`.

## Authorization and history

- `config.authorize_with :cancancan` uses the app's `Ability`. Keep the `:rails_admin` subject (see Naming).
- `config.authorize_with :pundit` calls the record's policy with `<action>?` methods (`index?`, `edit?`, `dashboard?`) and scopes lists with `policy_scope`.
- `config.authorize_with :action_policy` checks the same `<action>?` rules with `allowed_to?` and scopes lists with the policy's default `relation_scope`. `new?` resolves to `create?` and undefined rules to `manage?`. A model with no policy is checked against `ApplicationPolicy`, and one with no default relation scope lists nothing.
- `config.authorize_with do ... end` runs a custom block as a before filter.
- `config.authenticate_with do ... end` and `config.current_user_method do ... end` wire in the app's authentication, such as Devise or Warden.
- `config.audit_with :paper_trail` turns on the history action. Read the "History / audit table" section of `<gem>/docs/UPGRADING.md` first.

## Frontend

- The host app must use Propshaft and importmap-rails. There is no Sprockets, Webpacker, Webpack, Vite or build step, and there is no `config.asset_source` option.
- The engine runs its own Stimulus application, exposed as `window.RailsAdminNext.application`. Register custom controllers on that instance, not on the host's Stimulus app.
- Add JavaScript to the admin through a host config/importmap.rails_admin.rb. The engine appends it after its own map, so it can add pins or override the entrypoint pin. The engine's pin names are in `<gem>/config/importmap.rails_admin.rb`.
- There is no jQuery, jQuery UI, Bootstrap JS or `@rails/ujs`. Confirmations use Turbo's `data-turbo-confirm`.
- Date and time fields are native HTML5 inputs, with no flatpickr. Rich text is ActionText/Trix. There are no CDN editors such as CKEditor, CodeMirror or froala.
- The admin supports only the latest Chrome and Safari, so modern CSS and DOM APIs are fair game.

## Theming

Engine CSS sits in the cascade layers `ra.tokens`, `ra.framework` and `ra.skin`, so any unlayered host rule wins without specificity tricks. Rebrand by overriding `--ra-*` tokens, for example `:root { --ra-primary: #663399; }`. Upstream `--bs-*` variables do nothing here. The supported tokens and the `--bs-*` to `--ra-*` mapping are in the "Styling" section of `<gem>/docs/UPGRADING.md`. Dark mode follows the OS. `config.color_scheme = :light` (or `:dark`, or `:auto`) pins it.

## Security

The engine always enforces these, and there is no option to weaken them: CSRF, `X-Frame-Options: SAMEORIGIN`, non-GET export, confirmation on delete, and visible-field slicing of submitted attributes. A Content Security Policy is opt-in through `config.content_security_policy do |policy| ... end`. Pass `report_only: true` while tuning it. Read `<gem>/docs/security.md` before writing the policy. It lists the inline styles that still need `:unsafe_inline` in `style-src`.

## Never suggest

Mongoid, `RailsAdmin.config`, `rails_admin do` blocks, Font Awesome icon classes, jQuery plugins, Sprockets or Webpacker setup, or a migration from upstream RailsAdmin. The migration is a one-time rename, and `<gem>/docs/UPGRADING.md` covers it.
