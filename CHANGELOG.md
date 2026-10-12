# Changelog

## Unreleased

### Added

- `devise_for` expands into the routes Devise actually generates, so `/sign_in` is
  searchable as the path the app really serves. `path:`, `path_names:`, `only:` and `skip:`
  all move the paths with them, and the table is read off Devise's own
  `lib/devise/rails/routes.rb`. Only roles the app overrides with `controllers:` are
  expanded — a role Devise serves from its own controllers has no class in the repo to point
  at. `omniauth_callbacks` keeps a `DEVISE <path>/auth` marker, since its real paths come
  from the model's `omniauth_providers`, which a routes file can't see.

- `persists` now covers ActiveRecord's whole write surface, not just
  `create`/`update`/`save`. `update_columns`, `update_column`, `update_attribute`, `touch`,
  `destroy!`, `delete_by`, `destroy_by`, `create_or_find_by`, `insert_all!`, the bang
  increment/decrement/toggle methods and `update_counters`/`reset_counters` all reach the
  database, and a write through any of them was either invisible or filed as a generic
  `invokes`. The names are read off ActiveRecord's own source and judged one at a time,
  because the name doesn't tell you: `increment!` runs an UPDATE while `increment` only
  changes an attribute in memory. Those in-memory lookalikes stay out, as do
  `increment_counter`/`decrement_counter`, whose names metrics clients also claim.

### Fixed

- A class is now attributed to the file that defines it rather than the first one read.
  Node identity went by reading order, which is path order, so a file opening a class only
  to nest something under it could beat the real definition from an earlier-sorting
  directory. In one real app `app/interactors/task/configurator.rb` beat
  `app/models/task.rb`, which typed `Task` an interactor — and because a write survives
  only when it lands on a model, every one of the 83 writes to that model was dropped.
  `lupa where` pointed at the wrapper too. The file the autoloader would load the constant
  from now wins; a namespace no file spells is unaffected.

- A `devise_for` mount no longer labels its routes with a path the app doesn't serve.
  `devise_for :patients, path: ''` mounts its session at `/sign_in`, but was recorded as
  `DEVISE /patients/sessions`, which reads like a URL and was never one.

## 0.3.0 — 2026-10-11

Routes now match what `rails routes` reports, and gem-generated code is read through a
seam rather than hardcoded. Devise is the first gem through it.

### Added

- `resources` and `resource` expand into their REST actions, honoring `only:`, `except:`,
  `controller:`, `path:` and `module:`. Nested resources sit under the parent's
  `:parent_id`, and `member`/`collection` routes are recorded, as a block or with `on:`.
- `root` routes, and `scope "path"` / `scope path:` prefixes.
- Verbs without `to:` follow Rails' rules: a slashed path reads as controller/action
  (`post "stripe/update"`), a plain one routes to the enclosing namespace's controller, and
  `action:`, `controller:`, `scope controller:` and `controller :x do` are honored.
- `get :a, :b` records one route per action, and `match ... via:` one route per verb.
- `root` honors `controller:` and `action:`.
- An engine's own `X::Engine.routes.draw` block routes to controllers under `X::`.
- Gem conventions live in `lib/lupa/integrations/`, one module per gem, each keyed on that
  gem's own vocabulary so an app that doesn't use it records nothing.
- Devise scopes are read from the app's `devise_for` mounts, which is what calls
  `Devise.add_mapping` and so what names every helper. A write through the record accessor
  resolves (`current_patient.update` → `Patient`, and `devise_for :otc, class_name: "Patient"`
  → `current_otc` → `Patient`). A model's own `devise` call declares nothing: it only includes
  modules, so reading a scope off the class name would invent `current_user` for
  `devise_for :members, class_name: "User"`.
- New `authenticates` edge: `before_action :authenticate_patient!` → `Patient`, answering what
  must be signed in to reach a controller. `skip_before_action` is not read as a requirement,
  since it exempts actions rather than demanding the scope. Helpers no mount declares —
  `authenticate_csv!`, or `authenticate_user!` in an app with no `User` — are dropped, not
  guessed.

### Changed

- Route nodes are named `VERB /path #action` (e.g. `GET /orders/:id #show`), so the action
  survives even though the edge only names the controller.

### Fixed

- `resources :x, only: []` no longer records a route.
- A route only reaches the controller Rails names in full. It no longer falls back to a
  unique short name, which pointed `rails/health#show` at `Api::V1::HealthController`.
- A `to:` that names no controller — `redirect(...)`, a proc, a Rack app — drops the route
  instead of reading an action off the path and pairing it with the enclosing namespace.
- A `concern` body is skipped. Its verbs belong to wherever `concerns:` names it, not to the
  scope the concern is defined in.
- A `devise_for` inside a `namespace` or `scope` labels its routes with that path prefix, like
  every other route.

## 0.2.0 — 2026-10-07

The first tagged release.

### Added

- `lupa impact NAME` lists everything one hop from NAME, in both directions, with `file:line`.
- `lupa path FROM TO` prints the shortest chains of edges between two classes, up to 6 hops.
- Edges now record their file, so a class that is reopened across files points to the right
  place.
- New edge types: `persists` (writes on a model or an association proxy), `emails` (mailer
  sends), `triggers` (AR lifecycle callbacks), `invokes` and `dispatches`.
- `routes` edges from `config/routes.rb` to controllers.

### Changed

- Constants resolve the way Ruby resolves them. `::X` means top level only. Otherwise lupa
  checks the enclosing namespaces, then the superclass chain, then the top level.
  Association targets follow Rails' owner-based lookup.
- Associations honor `class_name:`, and `polymorphic: true` associations are dropped.

### Fixed

- A class is never recorded as inheriting from itself. Pundit's `class Scope < Scope` now
  resolves to `ApplicationPolicy::Scope`.
- `::Avo::Current`-style root-anchored constants no longer resolve to an app class with the
  same short name.
- Association names are singularized correctly, and each file is parsed only once.
