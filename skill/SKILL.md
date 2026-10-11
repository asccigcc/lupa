---
name: lupa
description: Query a static code-interaction graph (SQLite) to trace how a Ruby/Rails codebase connects — which controller calls which interactor, organizer steps, model associations, job enqueues, includes, inheritance — instead of reading files. Use BEFORE grepping/reading to answer "what calls X", "what does X call", "where is X defined", "impact radius of X", or "how does A reach B". Triggers: tracing call chains, mapping controller→interactor/service flow, finding all callers of a class/job, understanding an unfamiliar Rails codebase.
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
lupa calls   CheckoutsController # what this class calls/enqueues/organizes, with file:line
lupa impact  CancelOrders        # everything one hop from it, in and out, with file:line
lupa path    FromClass ToClass   # shortest chains of edges from one to the other (≤6 hops, ≤10 chains)
lupa where   Order               # file:line where it's defined (matches namespaced too)
lupa stats                       # node kinds + edge counts (sanity check the scan)
lupa query   "SQL"               # arbitrary query against the schema below
```

`path` follows edges in their direction and skips markers, so "no path" means
no *static* chain — the real one may run through a `dispatches` fork or a
runtime-chosen organizer step. Walk `calls`/`impact` out from the start to see where the static chain stops.

## Schema

```
nodes(name TEXT PK, kind TEXT, file TEXT, line INTEGER)
edges(src TEXT, rel TEXT, dst TEXT, file TEXT, line INTEGER)
-- src/dst are node names; file:line is where the edge was found (a reopened
-- class can record edges outside the file that defines it)
```

- `kind`: controller, interactor, model, job, service, policy, mailer,
  component, serializer, concern, module, route, other.
- `rel`: `calls` (`Const.call`), `enqueues` (`perform_later/async/...`),
  `organizes` (Interactor::Organizer steps), `invokes` (any other
  `Const.class_method(...)` on a repo constant; the ActiveRecord query surface —
  `find`/`where`/`create`/`new`/… — is excluded, but scopes and custom class
  methods are kept), `persists` (the *write* subset of that surface —
  `create!`/`update`/`destroy`/… — on a model constant or an association proxy
  `x.orders.create!`, resolved to the model; this is how a controller/service
  reaches a model — and a Devise accessor counts, so `current_patient.update`
  is a write on `Patient`), `authenticates` (see below), `association` (has_many/belongs_to/…, honoring an explicit
  `class_name:` and falling back to the Rails naming convention; `polymorphic:
  true` is dropped), `emails` (`SomeMailer.action(...).deliver_later`/`deliver_now`
  — the mail-send analog of `enqueues`; the mailer-action call is recorded as
  this instead of a generic `invokes`), `includes`, `inherits`, `dispatches`,
  `triggers`, `routes`.
- `authenticates` answers **"who has to be signed in to reach this?"**:
  `before_action :authenticate_patient!` -> the model that Devise scope
  authenticates. Use it to find the auth boundary of a controller, or to list
  everything one role can reach:
  `lupa query "SELECT src FROM edges WHERE rel='authenticates' AND dst='Provider'"`.
  Two cautions. It records the *declaration*, so a controller that inherits the
  filter from `ApplicationController` has no edge of its own — follow `inherits`.
  And `skip_before_action` is not recorded, so an edge means "this class declares
  the filter", not "every action requires it"; read `only:`/`except:` in the file
  to get per-action truth.
- `routes` connects the HTTP layer to a controller. The `route` node is named
  `VERB /path #action`, e.g. `GET /patients/:patient_id/orders/:id #show` or
  `DEVISE /patients/registrations`, and the edge points at the controller.
  Start a trace from a URL here: find the route with
  `lupa query "SELECT src, dst FROM edges WHERE rel='routes' AND src LIKE '%/orders%'"`,
  or list the routes that reach a controller with `lupa callers SomeController`.
  `resources`/`resource` expand into their REST actions, honoring `only:`/`except:`,
  `controller:`/`path:`/`module:`, nesting, and `member`/`collection` (block or
  `on:`). Also covered: explicit `to:`/hash-rocket routes, `root`, `devise_for
  controllers:`, `namespace` and `scope` (module and path).
  Edges are per class, not per action. So `lupa calls SomeController` lists what
  the whole controller calls; read the action's method to see what that one route does.
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
-- Full controller→interactor handoff map
SELECT src, dst, file, line FROM edges WHERE rel='calls'
  AND src IN (SELECT name FROM nodes WHERE kind='controller');

-- Classes that include a concern
SELECT src FROM edges WHERE rel='includes' AND dst='Trackable';
```

## Trust model — important

lupa only records a resolved edge when the receiver constant resolves to a
class/module defined in the repo, using Ruby's lexical lookup (`::X` is
top-level; a bare name binds in the enclosing namespace, then the superclass
chain, then the top level). Calls on local
variables and ambiguous short constant names are **dropped, not guessed** — so the graph **under-reports
rather than lies**. Treat a missing edge as "not statically resolvable," not
"definitely absent." Dynamic constant dispatch is the exception: instead of
vanishing, it's recorded as a `dispatches` marker so you can see where a chain
forks — follow it by reading the named receiver. For other runtime/metaprogrammed
dispatch, fall back to reading the file or a runtime tool.

## Gem conventions, and teaching lupa a new one

Beyond Rails itself, lupa reads a few gems that generate code — currently Devise,
which is why `current_patient.update` resolves to `Patient` and
`before_action :authenticate_patient!` is an `authenticates` edge. Each one keys
on that gem's own vocabulary, so an app not using it records nothing.

If a convention is missing and you are **working in the lupa repo itself**, the
contract and a step-by-step recipe are in `docs/integrations.md` — follow it
rather than inventing a shape; the seams already exist. From a host app, this is
read-only context: a gem lupa doesn't know is a reason an edge is absent.
