# lupa 🔍

[![CI](https://github.com/asccigcc/lupa/actions/workflows/ci.yml/badge.svg)](https://github.com/asccigcc/lupa/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

lupa builds a static graph of how the classes in a **Rails** app connect and stores it in
SQLite, so an agent can answer *"what calls X / what does X call / where is X defined"* with
one query instead of reading dozens of files.

## What it is

lupa is a **static analysis** tool. It builds a **static call graph** extended with dependency
edges, which is the kind of structure often called a **code knowledge graph**.

- **Static analysis:** lupa reads the source code without running it. Prism parses each file
  into an AST (abstract syntax tree), and lupa walks that tree.
- **Call graph:** the nodes are the app's classes and modules, and the edges say who calls
  whom. lupa's edges are *typed* (`calls`, `enqueues`, `association`, `inherits`, …), so the
  graph shows the kind of each handoff as well as the fact that it happens.
- **Knowledge graph:** the graph is stored as data you can query with SQL, not as a picture.

lupa doesn't use NLP or embeddings. It doesn't search text by similarity. Every edge comes
from a specific line of code, and the graph records that `file:line`.

## Why

When an AI agent traces a Rails request, it follows the path controller → service → job →
mailer by grepping and opening file after file. That uses a lot of tokens and still misses
steps. Generic indexers don't help much here. They see method calls, but not the Rails
conventions that actually connect the code: `perform_later`, associations resolved by naming
convention, `routes.rb`, and Pundit scopes.

lupa records exactly those handoffs. It parses the code with
[Prism](https://github.com/ruby/prism) and never boots the app, so there is no database, no
credentials and no environment setup. A scan of a large app takes about 1–2 seconds.

## Scope

- **Rails only.** lupa assumes the Rails layout (`app/`, `config/routes.rb`) and its
  conventions. It isn't a general Ruby indexer.
- **Static and constant-based.** It captures a handoff when the target is a constant it can
  resolve to a class defined in the repo.
- **Precision over recall.** If lupa can't resolve a target, it drops the edge instead of
  guessing. A missing edge means "not statically resolvable", not "doesn't happen".
  Dynamic dispatch (`constantize`) is kept as a visible `dispatches` marker so you can see
  where a chain forks.
- **A few gems beyond Rails itself.** Devise generates code, so its conventions are read too
  (`lib/lupa/integrations/`). Each one keys on that gem's own vocabulary, so an app that
  doesn't use it matches nothing — there is nothing to detect and nothing to configure.

## What it captures

| rel | from → to |
|-----|-----------|
| `calls` | `SomeService.call(...)` |
| `enqueues` | `SomeJob.perform_later/async/...` |
| `invokes` | any other `SomeClass.class_method(...)` on a repo constant |
| `persists` | a write (`create!`/`update`/`destroy`/…) on a model constant or an association proxy (`patient.orders.create!`) → the model |
| `emails` | `SomeMailer.action(...).deliver_later/deliver_now` → the mailer |
| `authenticates` | `before_action :authenticate_patient!` → the model that Devise scope authenticates |
| `association` | `has_many` / `belongs_to` / … (`class_name:` if given, else naming convention) |
| `includes` | concern/module includes |
| `inherits` | superclass |
| `dispatches` | a `constantize` / `safe_constantize` fork — target computed at runtime |
| `triggers` | an AR lifecycle callback (`after_create_commit :notify`) → the method it runs (a marker, not a node) |
| `routes` | a route (`GET /orders/:id #show`) → the controller it points at; `resources` and `devise_for` expand into the routes they generate |

A few rules worth knowing:

- `invokes` leaves out the ActiveRecord query surface (`find`, `where`, `new`, …) so real
  business calls aren't buried under `Model.find`. Scopes and custom class methods are kept.
- `persists` resolves an association proxy by its name across the app (`orders` → `Order`).
  If the same name points at different models in different places, lupa drops it.
- The same lookup covers helpers a gem generates. Each `devise_for` declares a scope, so
  `current_patient.update(...)` is a write on `Patient` and `before_action
  :authenticate_patient!` is an `authenticates` edge to it — derived from that app's own
  mounts, never from a list of likely names. A helper no mount declares (`current_user` in an
  app with no `User`) stays unresolved.
- Constants are looked up the way Ruby does it. `::X` means top level only. Otherwise lupa
  checks the enclosing namespaces first, then the superclass chain, then the top level.
  Association targets follow Rails' own owner-based lookup.

## Install

Add it to the app's Gemfile. The `lupa` name on RubyGems belongs to an unrelated gem, so
point Bundler at GitHub:

```ruby
group :development do
  gem "lupa", github: "asccigcc/lupa", tag: "v0.3.0", require: false
end
```

```bash
bundle install
bundle exec lupa scan
```

To give Claude Code the bundled skill, link it:

```bash
ln -sfn "$(bundle info lupa --path)/skill" ~/.claude/skills/lupa
```

Or install lupa once for every repo on the machine. This installs the gem and links the skill:

```bash
git clone git@github.com:asccigcc/lupa.git
cd lupa && ./install.sh
```

Requires **Ruby 3.3+** and the **`sqlite3`** binary.

## Use

```bash
lupa scan                      # builds tmp/lupa.db
lupa stats
lupa callers Order::Finalize   # who calls it, with file:line
lupa calls   CheckoutsController
lupa impact  CancelOrders      # everything one hop away, in and out, with file:line
lupa path    ChurnkeyController PartnerApiFillRequestJob   # shortest chains between two classes
lupa where   Order
lupa query   "SELECT ... FROM edges WHERE ..."
```

The graph is stored per repo at `tmp/lupa.db`. See `skill/SKILL.md` for the schema and more
example queries.

## Limitations

- Calls on local variables and metaprogrammed dispatch aren't captured.
- Constants that are reachable only through an included module aren't resolved.
- `polymorphic: true` associations are dropped because they have no single target.
- `new`/`build` followed by `save` isn't counted as a write yet.
- Edges are recorded per class, not per action. A route leads to its controller, and from
  there `calls` lists what the whole controller calls, not only that action.
- Routes don't cover constraints, `concern`s, or a namespace wrapped around a `draw` call
  (each drawn file is read on its own). An engine's routes are recorded relative to where
  it's mounted.
- `devise_for` expands into the paths Devise really serves, honoring `path:`, `path_names:`,
  `only:` and `skip:` — but only for the roles the app overrides with `controllers:`. A role
  Devise serves from its own controllers has no class in the repo, so it's dropped.
  `omniauth_callbacks` keeps a `DEVISE <path>/auth` marker instead of routes, since its paths
  are built from the model's `omniauth_providers`. A non-default `sign_out_via` isn't read.

## Development

```bash
bundle install
bundle exec rspec        # runs against spec/fixtures/repo, a tiny fake app
bundle exec rubocop      # enforces the Sandi Metz sizing rules
```

## License

[MIT](LICENSE) © 2026 asccigcc
