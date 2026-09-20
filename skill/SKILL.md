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
  component, serializer, concern, module, other.
- `rel`: `calls` (`Const.call`), `enqueues` (`perform_later/async/...`),
  `organizes` (Interactor::Organizer steps), `association`
  (has_many/belongs_to/…, resolved by Rails naming convention), `includes`,
  `inherits`.

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

lupa only records an edge when the receiver constant resolves to a class/module
defined in the repo. Calls on local variables, dynamic dispatch, and
`class_name:` association overrides are **dropped, not guessed** — so the graph
**under-reports rather than lies**. Treat a missing edge as "not statically
resolvable," not "definitely absent." For runtime/metaprogrammed dispatch, fall
back to reading the file or a runtime tool.
