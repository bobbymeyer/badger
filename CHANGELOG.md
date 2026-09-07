# Changelog

## 0.2.0 — 2026-09-07

The engine, aligned with the tools beside it. The core is unchanged and moves with it.

### Changed

- **Dressed by Pandatone's dresser.** The catalogue, the client, the palette and colour readers, the luminance measure, the snapshot, the picker, the swatches and the drift sentences were the engine's copy of Stripeclub's; they are `Pandatone::Dresser` now. `Badger.palette_source`, `pandatone_url` and `pandatone_token` are gone: with no `PANDATONE_URL` the dresser asks the Pandatone in the same process, and with one it asks that Pandatone over HTTP. The engine's gemspec depends on `pandatone`.
- **A rule is for a rank.** `badger_slot_rules.slot` is `rank`, and an assigned rule's setting is `slot` — the position in the palette — where it was `index`. The v1 colorway resource says `rank` and `settings.slot` accordingly; the API is unreleased, so v1 changes in place.
- **Set on its-swiss 0.8.** Every page opens with the library's page head. The index is cards on the page's own fields, narrowed by a search that filters as you type and by two registers: what the badge is wearing, and the order. The grid is set once, in the layout, so the editor's pages are on it too.
- **The engine ships its JavaScript the way Pandatone does**: a module the layout imports registers its controllers, and the engine pins its own files. The first controller is small: in the document, Tab indents and Shift-Tab dedents rather than leaving the field.
- The stylesheets read the library's `--rule-hair`; the `--rule-hairline` they read before was no token at all, and every border fell through to its fallback.

### Acceptance

- The three reference badges — Stockholm Stadion, Le Dive, Giletti — hold as acceptance tests under `test/acceptance/`, each against its photograph.



The first cut: the core gem (arc-length spines, follow, regions, fits, the container tree, union scope and knockout, colour slots and the output contract, primitives and illustration, the declarative Spec) and the Rails engine (badges as documents, colorways against Pandatone, a read-only API described by OpenAPI).
