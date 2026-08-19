# Upstream parity

Assessed through upstream `0690a5e6` (2026-08-08). Fork point: `d8e0809e` (2025-09-14).

Divergence from the fork point: 771 files, +20,217 / −73,168 lines.

## How this fork tracks upstream

RailsAdminNext is a hard fork of [railsadminteam/rails_admin](https://github.com/railsadminteam/rails_admin). It is **never merged or rebased from upstream**, and it cannot be: the fork deleted whole subsystems upstream still ships — the Mongoid adapter, the npm/webpack build, jQuery and `@rails/ujs`, Bootstrap's JavaScript, Appraisal, CarrierWave. Replaying this fork's history onto a moving upstream would conflict with every commit touching any of them, by construction.

Instead, upstream work is absorbed by **reimplementation**: read the upstream commit, judge whether the underlying problem exists here, and write the fix in this codebase's terms. A port therefore need not — and often should not — match upstream's diff. Deliberate divergences are recorded below so they are not "corrected" back later.

This means `git rev-list --count upstream/master...master` is not a progress measure. It counts commits never merged, so it does not fall when work is absorbed and it grows every time upstream moves. **This ledger is the state.** The watermark above records what has been assessed; the table records the verdict for each commit, including the ones deliberately skipped.

## Verdicts

Commits are listed newest first, as `git log` reports them.

| upstream | subject | verdict | ours |
|---|---|---|---|
| `0690a5e6` | Start development for 4.0.0 | n/a — upstream release chore | — |
| `50fbbcd9` | Remove @babel/runtime as a direct dependency | n/a — no npm build here | — |
| `e4ad87b7` | Replace deprecated jQuery functions with native ones | n/a — jQuery removed | — |
| `77e5d0bc` | Improve intermittent autocomplete failures due to stale element | n/a — measured: the widget stamps and aborts its own requests, and each query renders once | [#18](https://github.com/6temes/rails_admin_next/issues/18) |
| `26bb8763` | Declare JavaScript package is a module | n/a — no npm package | — |
| `336845f4` | Remove string mutation | adapted | [#16](https://github.com/6temes/rails_admin_next/pull/16) |
| `b72badeb` | Add a "sass" entry point to package.json | n/a — no npm/webpack build | — |
| `9b21e3ba` | Update rails/ujs NPM package | n/a — UJS removed, Turbo replaces it | — |
| `ca2d0954` | Use a non-beta trix package in dummy_app | n/a — trix is self-hosted from `action_text-trix`, not an npm pin | — |
| `1f681b48` | Add nonce to css/js tags | adapted — `csp_meta_tag` deliberately left out, see below | [#22](https://github.com/6temes/rails_admin_next/pull/22) |
| `54a23401` | Add belongs_to optional/required support to `required?` | adapted | [#13](https://github.com/6temes/rails_admin_next/pull/13) |
| `c18592a1` | Draw routes before the suite goes multi-threaded | adapted — premise corrected, see PR | [#17](https://github.com/6temes/rails_admin_next/pull/17) |
| `91e9cca8` | Resolve the inverse of a polymorphic association | adapted — 3 divergences, see below | [#14](https://github.com/6temes/rails_admin_next/pull/14) |
| `8bffeb61` | Pin vite-plugin-ruby below 5.2 | n/a — no vite | — |
| `9f03412d` | Fix RuboCop offense in main_controller_spec | n/a — linting is Standard Ruby | — |
| `17b64251` | Avoid carrierwave versions that pull in mimemagic | n/a — CarrierWave removed | — |
| `703e4894` | Add Rails 8.1 support | n/a — this fork is Rails ~> 8.1 only | — |
| `9881e254` | Add test for editing a nested one widget item | adapted — driven through this fork's markup | [#15](https://github.com/6temes/rails_admin_next/pull/15) |
| `47d913fe` | Fix flaky locale spec for Datetimepicker widget | n/a — native HTML5 date/time inputs replaced the widget | — |
| `ec685453` | Don't auto-require the appraisal gem | n/a — Appraisal removed | — |

## Standing divergences

Where a port deliberately differs from upstream's own patch. Each is correct *for this fork*; changing one to match upstream would reintroduce a bug.

**`Association#inverse_of`** (from `91e9cca8`) resolves the declared `inverse_of:`, then the inverse ActiveRecord resolves for the reflection, then a polymorphic `as:` — and honours `inverse_of: false`. Upstream reads only the declared option and `as`.

- The middle step exists because this fork is ActiveRecord-only. Upstream's adapter also serves Mongoid, which resolves no inverse, so `as` is the only source available to both. Without the middle step, a conventional pair that declares nothing on either side reports no inverse and keeps rendering its back-reference.
- Honouring `inverse_of: false` matters because `false.try(:to_sym)` is `nil`, so upstream's `|| as` silently reinstates an inverse the host explicitly declined.
- The order is load-bearing. Reading the declared option first is what keeps a polymorphic `belongs_to` that declares an inverse from raising inside Rails' reflection, where the class cannot be computed.

**`FormBuilder#nested_field_association?`** (from the same commit) limits its hoisted name-match branch to association fields. Upstream's hoist is unconstrained. A polymorphic `as:` is never validated against the child class, so without the limit a plain column sharing that name can be suppressed from a subform.

**`sanitize_params_for!`** drops the parent's inverse from the nested allowlist, which upstream does not do at all — its permitted keys are derived purely from the visible fields. Hiding the back-reference without narrowing the allowlist left a collection subform re-parentable through a crafted `<assoc>_attributes[n]`, since `assign_nested_attributes_for_collection_association` assigns straight onto an already-associated record ([#24](https://github.com/6temes/rails_admin_next/pull/24)).

**The engine's stylesheet and style-preload tags carry the CSP nonce** (from `1f681b48`), but `csp_meta_tag` does not ship. Turbo reads that meta to re-nonce scripts it re-activates, and this engine renders no body script for it to re-activate; the nonce generator here is also per-request random, which a cached Turbo snapshot would carry stale. Adding the meta wants that generator decision alongside it.

## Assessing the next batch

```bash
git fetch upstream
git log --oneline 0690a5e6..upstream/master
```

Triage each commit by the **underlying problem**, not by the API, selector, or library its diff happens to touch. State the problem without naming any of them; if that sentence describes something possible here, the commit is relevant even when its diff is entirely in code this fork deleted.

`77e5d0bc` above is the cautionary case, and it cuts both ways. It was first dismissed as jQuery-UI-only, which was the wrong reason — the race it describes is stated in terms of a selector, and dismissing it on that vocabulary is exactly the mistake the rule above exists to prevent. But the CI failure that seemed to confirm the re-triage turned out to be an unrelated bug: an example reading the database before the server had answered ([#23](https://github.com/6temes/rails_admin_next/pull/23)). The widget itself stamps and aborts its requests, and instrumenting it showed one render per query, so the upstream race has no counterpart here.

**A coincident failure is not confirmation.** Look past a commit's vocabulary to decide whether it *could* apply, then measure this fork's own code before concluding that it does.
