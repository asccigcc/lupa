# Changelog

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
