# lupa 🔍

[![CI](https://github.com/asccigcc/lupa/actions/workflows/ci.yml/badge.svg)](https://github.com/asccigcc/lupa/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A static **code-interaction graph** for Ruby/Rails codebases, built for AI coding
agents. It parses a repo with [Prism](https://github.com/ruby/prism) (no Rails
boot, ~1s for a large app) and stores how classes connect in a small SQLite
database, so an agent can answer *"what calls X / what does X call / where is X
defined"* with one query instead of reading dozens of files.

It exists because generic tree-sitter indexers don't understand Rails, and
reading files to trace call chains burns tokens. lupa is tuned to the constant-based
handoffs Rails actually uses.

## What it captures

| rel | from → to |
|-----|-----------|
| `calls` | `SomeInteractor.call(...)` |
| `enqueues` | `SomeJob.perform_later/async/...` |
| `organizes` | `Interactor::Organizer` steps |
| `invokes` | any other `SomeClass.class_method(...)` on a repo constant |
| `persists` | a write (`create!`/`update`/`destroy`/…) on a model constant or an association proxy (`patient.orders.create!`) → the model |
| `emails` | `SomeMailer.action(...).deliver_later/deliver_now` → the mailer |
| `association` | `has_many` / `belongs_to` / … (`class_name:` if given, else naming convention) |
| `includes` | concern/module includes |
| `inherits` | superclass |
| `dispatches` | a `constantize` / `safe_constantize` fork — target computed at runtime |
| `triggers` | an AR lifecycle callback (`after_create_commit :notify`) → the method it runs (a marker, not a node) |
| `routes` | a `config/routes.rb` entry → the controller it points at (`route` node → controller) |

**Trust model:** a resolved edge is recorded only when the receiver constant
resolves to a class/module defined in the repo. Calls on local variables and
`class_name:` overrides are **dropped, not guessed** — the graph under-reports
rather than lies. Two rels are **markers**, not resolved edges: `dispatches`
(dynamic dispatch can't be resolved, so lupa records a signpost keyed on the
receiver source, e.g. `dispatches → validate_action_class`, so the chain forks
*visibly* instead of vanishing) and `triggers` (a lifecycle callback's target is
a same-class method, not a constant, so `dst` is the method name — a lifecycle
entry point you can see when you read the node, not a traversable node link).

> `invokes` deliberately excludes the ActiveRecord query/persistence surface
> (`find`, `where`, `create`, `new`, …) so business-logic class-method calls
> aren't buried under a `Model.find` firehose. Scopes and custom class methods
> are arbitrary names and *are* recorded. The *write* subset of that surface —
> `create!`/`update`/`destroy`/… — is recovered separately as `persists` (below),
> because it names a specific model being written: a real handoff, not query noise.

> `persists` is how lupa follows a controller/service into a model without booting
> Rails. It fires on a model constant (`Order.create!`) or an **association proxy**
> (`patient.orders.create!` → `Order`, resolving `orders` through the app-wide
> association graph). Reads (`find`/`where`) and `new`/`build` are excluded; an
> ambiguous association name (one that targets different models in different
> places, e.g. `child`) is dropped, not guessed; and the target must resolve to a
> model, so `SomeService.create`-style writes on non-models never leak in.

## Install

lupa is a gem. Clone and run the installer, which builds & installs the gem
(putting `lupa` on PATH via RubyGems) and links the Claude skill into
`~/.claude/skills`:

```bash
git clone git@github.com:asccigcc/lupa.git
cd lupa && ./install.sh
```

Or manage it yourself:

```bash
gem build lupa.gemspec && gem install ./lupa-*.gem   # just the CLI
```

Prereqs: **Ruby 3.3+** (Prism ships built in) and the **sqlite3** binary.

## Use

```bash
cd /path/to/any/rails/repo
lupa scan                      # builds tmp/lupa.db (gitignored in most repos)
lupa stats
lupa callers Order::Finalize   # who calls it, with file:line
lupa calls   CheckoutsController
lupa where   Order
lupa query   "SELECT ... FROM edges WHERE ..."
```

Once installed, the bundled Claude skill teaches Claude Code to reach for `lupa`
before grepping/reading when tracing structure. See `skill/SKILL.md` for the
full query cookbook and schema.

## Portability

Clone on any machine, run `./install.sh`, then `lupa scan` in any repo. The graph
is per-repo at `<repo>/tmp/lupa.db`; one install serves every project. The gem
executable pins its own Ruby, so it works even inside repos that pin a different
version manager ruby.

## Limitations (it's young)

- Rails/Ruby only; constant-based handoffs only (no runtime/metaprogrammed dispatch).
- `association` targets honor an explicit `class_name:`, fall back to the naming
  convention otherwise, and drop `polymorphic: true` (no single target).
- Ambiguous short constant names that can't be uniquely resolved are dropped.
- `persists` resolves an association proxy by **name** (`orders` → `Order`), not by
  typing the receiver — so it can't tell two same-named associations apart and
  drops the name when it targets different models across the app. `new`/`build`
  aren't counted as writes yet.
- `routes` are parsed statically (no `rails routes` boot): explicit `to:`/hash-rocket
  routes, `devise_for controllers:`, and `resources`/`resource` with
  `namespace`/`scope module:` prefixing. The long tail — the individual REST paths
  a `resources` expands to, `member`/`collection`, constraints, mounted engines —
  is under-reported.

## Development

```bash
bundle install
bundle exec rspec        # suite runs against spec/fixtures/repo, a tiny fake app
bundle exec rubocop      # enforces the Sandi Metz sizing rules (see .rubocop.yml)
```

## License

[MIT](LICENSE) © 2026 asccigcc
