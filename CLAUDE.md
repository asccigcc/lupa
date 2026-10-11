# CLAUDE.md

lupa builds a static interaction graph of a Rails app by parsing it with Prism —
no Rails boot, no database. The graph is SQLite, written through the `sqlite3`
binary (there is no `sqlite3` gem dependency, deliberately: a native extension in
every host app is not worth it).

```bash
bundle exec rspec       # tests
bundle exec rubocop -a  # lint; enforces the Sandi Metz limits
./install.sh            # build + install the gem, symlink skill/ into ~/.claude/skills
```

## The one rule everything else serves

**Precision over recall.** If a target cannot be resolved to a class defined in
the repo, the edge is dropped — never guessed. "The graph under-reports rather
than lies" is the promise the tool is built on, and a wrong edge costs more than
a missing one because an agent cannot tell it is wrong.

Dynamic dispatch is the one exception, kept as a visible `dispatches` marker.

## Gem conventions

Knowledge of a specific gem goes in `lib/lupa/integrations/`, one module per gem.
**Read `docs/integrations.md` before adding or changing one** — it is the contract
plus a step-by-step recipe, and each invariant in it was paid for by a bug.

Always read a gem's own source at the version in the host app's `Gemfile.lock`
rather than writing its API from memory. Both bugs this seam has had so far came
from assuming a convention instead of checking it.

## Changing what the graph records

Any change to walking, recognizing or resolving needs a **parity scan** against a
real app before it ships: new edges must be exactly what you intended and nothing
may be lost. The procedure is in `docs/integrations.md`.

A fixture that only proves the happy path proves little. Add the negative case —
the lookalike that must drop — in `spec/fixtures/repo/`.

## Workflow

`main` is protected; changes land through a PR. Keep `CHANGELOG.md`, the rel table
in `README.md` and the rel list in `skill/SKILL.md` in step with the code — the
skill is what an agent actually reads, so a rel missing from it is invisible.
