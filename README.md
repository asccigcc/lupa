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
| `association` | `has_many` / `belongs_to` / … (`class_name:` if given, else naming convention) |
| `includes` | concern/module includes |
| `inherits` | superclass |
| `dispatches` | a `constantize` / `safe_constantize` fork — target computed at runtime |

**Trust model:** a resolved edge is recorded only when the receiver constant
resolves to a class/module defined in the repo. Calls on local variables and
`class_name:` overrides are **dropped, not guessed** — the graph under-reports
rather than lies. The one exception is `dispatches`: dynamic dispatch can't be
resolved, so instead of dropping it silently lupa records a marker keyed on the
receiver source (e.g. `dispatches → validate_action_class`) so the chain forks
*visibly* — telling you where to look rather than pretending nothing happens.

> `invokes` deliberately excludes the ActiveRecord query/persistence surface
> (`find`, `where`, `create`, `new`, …) so business-logic class-method calls
> aren't buried under a `Model.find` firehose. Scopes and custom class methods
> are arbitrary names and *are* recorded.

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

## Development

```bash
bundle install
bundle exec rspec        # suite runs against spec/fixtures/repo, a tiny fake app
```

## License

[MIT](LICENSE) © 2026 asccigcc
