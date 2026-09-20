---
name: lupa
description: Query a static code-interaction graph (SQLite) to trace how a Ruby/Rails codebase connects — which controller calls which interactor, organizer steps, model associations, job enqueues, includes, inheritance — instead of reading files. Use BEFORE grepping/reading to answer "what calls X", "what does X call", "where is X defined", or "impact radius of X". Triggers: tracing call chains, mapping controller→interactor/service flow, finding all callers of a class/job, understanding an unfamiliar Rails codebase.
---

# lupa

`lupa` is a CLI that builds and queries a static graph of how a Ruby/Rails
codebase connects. Answer structural questions with one query instead of
reading many files.

## First: make sure the graph exists and is fresh

The graph lives at `<repo>/tmp/lupa.db`. If it is missing or the code changed
materially since the last scan, rebuild it (fast, ~1s for a large app, no Rails boot):

```bash
lupa scan            # run from the repo root; scans app/ if present, else whole repo
```

## Query it

```bash
lupa callers Order::Finalize     # who calls/enqueues/includes/inherits this (with file:line)
lupa calls   CheckoutsController # what this class calls/enqueues/organizes, in order
lupa where   Order               # file:line where it's defined (matches namespaced too)
lupa stats                       # node kinds + edge counts (sanity check the scan)
lupa query   "SQL"               # arbitrary query against the schema below
```

## Schema

```
nodes(name TEXT PK, kind TEXT, file TEXT, line INTEGER)
edges(src TEXT, rel TEXT, dst TEXT, line INTEGER)   -- src/dst are node names
```

- `kind`: controller, interactor, model, job, service, policy, mailer,
  component, serializer, concern, module, route, other.
- `rel`: `calls` (`Const.call`), `enqueues` (`perform_later/async/...`),
  `organizes` (Interactor::Organizer steps), `invokes` (any other
  `Const.class_method(...)` on a repo constant; the ActiveRecord query surface —
  `find`/`where`/`create`/`new`/… — is excluded, but scopes and custom class
  methods are kept), `association` (has_many/belongs_to/…, honoring an explicit
  `class_name:` and falling back to the Rails naming convention; `polymorphic:
  true` is dropped), `emails` (`SomeMailer.action(...).deliver_later`/`deliver_now`
  — the mail-send analog of `enqueues`; the mailer-action call is recorded as
  this instead of a generic `invokes`), `includes`, `inherits`, `dispatches`,
  `triggers`, `routes`.
- `routes` connects the HTTP layer to a controller: a `route` node (e.g.
  `POST /things/bulk`, `DEVISE /patients/registrations`) → the controller it
  targets. Start a trace from a URL/path here — `lupa callers SomeController`
  lists the routes that reach it. Parsed statically, so it covers explicit
  `to:`/hash-rocket routes, `devise_for controllers:`, and `resources`/`resource`
  (with `namespace`/`scope module:` prefixing); it does **not** expand a
  `resources` into its individual REST paths.
- `dispatches` is special: a `constantize`/`safe_constantize` call whose target
  is computed at runtime. `dst` is **not a node** — it's the receiver source
  (e.g. `validate_action_class`), a signpost that the chain forks dynamically
  *here*. Read that receiver/method to follow it; don't expect `callers` to find
  the far side.
- `triggers` is also a marker: an AR lifecycle callback (`after_create_commit
  :notify_patient`). `dst` is the **method name** it runs, a same-class method —
  **not a node**. It answers "what fires when this record is saved/created/…?" —
  a lifecycle entry point on the node. To follow it, read that method in the same
  class (its own outgoing edges, e.g. `emails`/`enqueues`, are recorded on the
  class node). `callers` won't traverse a `triggers` marker.

## Useful raw queries

```sql
-- Impact radius: everything one hop from X (in and out)
SELECT 'out' dir, rel, dst other, line FROM edges WHERE src='X'
UNION ALL
SELECT 'in'  dir, rel, src other, line FROM edges WHERE dst='X';

-- Full controller→interactor handoff map
SELECT src, dst, line FROM edges WHERE rel='calls'
  AND src IN (SELECT name FROM nodes WHERE kind='controller');

-- Classes that include a concern
SELECT src FROM edges WHERE rel='includes' AND dst='Trackable';
```

## Trust model — important

lupa only records a resolved edge when the receiver constant resolves to a
class/module defined in the repo. Calls on local variables and unresolvable
short constant names are **dropped, not guessed** — so the graph **under-reports
rather than lies**. Treat a missing edge as "not statically resolvable," not
"definitely absent." Dynamic constant dispatch is the exception: instead of
vanishing, it's recorded as a `dispatches` marker so you can see where a chain
forks — follow it by reading the named receiver. For other runtime/metaprogrammed
dispatch, fall back to reading the file or a runtime tool.
