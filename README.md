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
| `association` | `has_many` / `belongs_to` / … (by naming convention) |
| `includes` | concern/module includes |
| `inherits` | superclass |

**Trust model:** an edge is recorded only when the receiver constant resolves to
a class/module defined in the repo. Dynamic dispatch, calls on local variables,
and `class_name:` overrides are **dropped, not guessed** — the graph
under-reports rather than lies.

## Install

```bash
git clone <this-repo> lupa
cd lupa && ./install.sh        # symlinks `lupa` onto PATH + the skill into ~/.claude/skills
```

Prereqs: **Ruby 3.3+** (Prism ships built in; set `LUPA_RUBY` to pin one) and the
**sqlite3** CLI.

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
is per-repo at `<repo>/tmp/lupa.db`; one install serves every project.

## Limitations (it's young)

- Rails/Ruby only; constant-based handoffs only (no runtime/metaprogrammed dispatch).
- `association` targets are inferred from the symbol; `class_name:` is not read.
- Ambiguous short constant names that can't be uniquely resolved are dropped.

## Development

```bash
bundle install
bundle exec rspec        # suite runs against spec/fixtures/repo, a tiny fake app
```

The extractor is split into small, testable classes under `lib/lupa/`:
`Walker` (per-file AST visit), `Extractor` (globbing + constant resolution),
`SqlDump` (SQLite rendering). `lib/lupa/extract.rb` is the thin CLI entrypoint.
Coverage is enforced at 90% via SimpleCov; CI runs the suite on Ruby 3.3 and 3.4.

## License

[MIT](LICENSE) © 2026 asccigcc
