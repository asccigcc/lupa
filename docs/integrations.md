# Adding an integration

An integration teaches lupa one gem's conventions. Devise is the worked example
(`lib/lupa/integrations/devise/`); read it alongside this.

This document is the contract. Follow it rather than reinventing a shape — the
seams below already exist and the invariants below were each paid for by a bug.

## The contract

An integration is a module under `Lupa::Integrations`, listed in
`Integrations::ALL`, answering either or both hooks:

| hook | run by | sees |
|------|--------|------|
| `recognizers` | `Walker` | every call node in `app/**/*.rb` |
| `route_recognizers` | `RouteWalker` | every call node in the routes files |

Define only the hook you need; `Integrations.hook` selects by `respond_to?`.

A recognizer is anything answering `call(node, recorder) -> Boolean`, the same
duck the core recognizers are. Return **true only if you recorded something** —
true claims the node and stops later recognizers from seeing it.

Integrations run *before* the core recognizers in `Walker::RECOGNIZERS`, because
a gem's vocabulary is more specific than Rails'.

Write through the `Recorder`:

```ruby
recorder.add(node, "rel", dst)  # an edge from the enclosing class
recorder.declare(value)         # a finding assembled after the whole walk
recorder.current                # the class/module currently being defined
```

## The invariants

**1. Self-gate on the gem's own vocabulary, in the first line.**

```ruby
return false unless node.name == :devise_for
```

An app without the gem then matches nothing, which is why there is no detection
step, no config and no `Gemfile.lock` sniffing. If the gem's tell is *not*
distinctive — Avo's is `current_user`, which any app may define — gating must be
on path (`app/avo/**`) instead. That hook does not exist yet; add it rather than
gating on a name that will produce false positives.

**2. Derive every name from the app. Never hardcode a list of helpers.**

28H has 432 `current_user` call sites and no `User` model (they are Avo's). A
hardcoded Devise helper list would have invented a class.

**3. Read the gem's source at the version in `Gemfile.lock`. Never from memory.**

The scope-authority bug came from assuming a model's `devise` call created the
mapping. It does not — `devise_for` calls `Devise.add_mapping`, and the mapping
is what names every helper. Confirm *what generates the names* in the real
source before writing the recognizer.

**4. When the picture is app-wide, `declare` instead of resolving in place.**

A gem's conventions are usually app-specific, and the file that declares them may
be walked after the file that uses them. So a recognizer declares a value and the
app-wide picture is assembled once the walk is done. A declaration joins in by
answering a duck method, collected by `respond_to?`:

```ruby
# Integrations.accessors picks up anything answering `accessors`
def accessors
  [["current_#{name}", model, model]]  # [name, raw target, owner]
end
```

**5. Reuse a resolution strategy before inventing one.**

`authenticates` records the helper name verbatim and reuses `:model`, so the
`Resolver` needed no change at all. Only add to `Rel::RESOLUTION` when no
existing strategy fits, and update the comment at the top of `Rel` when you do.

**6. Precision over recall. An unresolvable target drops.**

Record the source name verbatim and let the index fail to resolve it. Never
substitute a guess. "The graph under-reports rather than lies" is the whole
trust model, and an integration is the easiest place to break it.

**7. Never read a negation as a declaration.**

`skip_before_action :authenticate_patient!` *exempts* actions. Recording it as a
requirement states the opposite of what the class says. Look for the revoking
form of whatever macro you match, and exclude it explicitly.

**8. Rails' vocabulary belongs in `Vocabulary`; the gem's pattern stays local.**

`before_action` is Rails, so `Vocabulary::FILTERS` holds it. `authenticate_X!` is
Devise, so the regexp lives in the integration.

## The recipe

1. **Read the gem source** at the locked version. Find what generates the names.
2. **Write the specs first.** A unit spec in `spec/lupa/integrations/<gem>_spec.rb`
   driving the recognizer through a `Walker`/`RouteWalker`, plus an end-to-end
   expectation in `spec/lupa/extractor_spec.rb`.
3. **Add fixtures** to `spec/fixtures/repo/`. Always include a **negative**: a
   lookalike that must drop (`authenticate_ghost!`) and, if the macro has one,
   its revoking form. A fixture that only proves the happy path proves little.
4. **Implement**, `module_function`, methods ≤5 lines, Sandi Metz limits enforced
   by `.rubocop.yml`.
5. **Register** the module in `Integrations::ALL`.
6. **Parity-scan a real app** (below). New edges must be exactly the rel you
   intended, and nothing may be lost.
7. **Document**: `CHANGELOG.md`, the rel table in `README.md`, and the rel list in
   `skill/SKILL.md` — including the limits, so an agent knows what the edge does
   *not* mean.

### Parity scan

The one check that matters: an integration must add only what it claims. Commit
first — the baseline worktree reads a commit, not your working tree.

```bash
cd /path/to/lupa
git worktree add -q --detach /tmp/lupa-base "$(git rev-parse HEAD~1)"

cd /path/to/a/real/rails/app
for v in base head; do
  dir=$([ $v = base ] && echo /tmp/lupa-base || echo /path/to/lupa)
  ruby $dir/exe/lupa scan >/dev/null
  sqlite3 tmp/lupa.db .dump | sort > /tmp/d-$v.sql
done
diff /tmp/d-base.sql /tmp/d-head.sql > /tmp/p.diff

echo "new:"  && grep '^>' /tmp/p.diff | grep "INSERT INTO edges" | awk -F"','" '{print $2}' | sort | uniq -c
echo "lost:" && grep '^<' /tmp/p.diff | grep "INSERT INTO edges" | awk -F"','" '{print $2}' | sort | uniq -c

cd /path/to/lupa && git worktree remove --force /tmp/lupa-base
```

Then reconcile the count against the source. If the app has 79 declaring call
sites, expect 79 edges; chase any gap before shipping rather than rounding it off.

### Spec gotchas

- A spec that wraps a body in `class X < ApplicationController` gets an
  `inherits` edge for free. Filter by the rel under test.
- `Ast.symbols` returns positional symbols only, so `only:`/`except:` values are
  already excluded. Add a spec proving it anyway.

## Deliberately not built

Loadable third-party plugins. lupa already carries gem knowledge in core, the gem
population is small and slow-moving, and a plugin API would mean a stable public
contract, versioning, discovery, and running third-party code against a codebase —
for no current user. `Lupa.register(MyIntegration)` is a few lines on this same
contract if that changes.

Pundit, Interactor and Sidekiq knowledge predates this seam and still lives in
core (`Resolver`, `Recognizers`, `Vocabulary`). That split is historical, not
principled. Move one only when it stops paying rent where it is.
