# Changelog

## Unreleased

### Fixed

- **A band's baseline goes on the edge the type grows away from.** A run's
  ink rises from its baseline along its own normal, and that normal turns
  with the run's direction: out of the badge over the top, into it under the
  bottom, and `reversed` flips both. `from:` defaulted to the inner edge for
  all of them, so half the sweeps set their type outside the band they name —
  `sweep: bottom` and `sweep: top, reversed: true` among them — and nothing
  said so. The edge is read off the run now. Documents that name `from:` are
  unchanged, including the references.

### Added

- **A note a builder leaves on a node comes out of `Output#warnings`.** The
  first one: type set from an edge it grows off is still set where the
  document asked, and now says it is growing out of the band. Nothing warned
  about that before, which is how six versions of the Ring shipped with its
  bottom word outside the ring.

### Changed

- **Nothing here pins a version of ours.** The gemspec asked for
  `pandatone >= 0.4` and `its-swiss ~> 1.0`; both had to be edited by hand
  when the other side moved, and neither could ever have been violated —
  Pandatone is taken from its main branch, and we are its only consumer.
  Pandatone carries no version requirement now, and its-swiss carries a floor
  with no ceiling, so a new major arrives with everything else. `badger` stays
  pinned to `Badger::VERSION`: the engine calls the core's internals, they
  ship from one repository, and the constraint writes itself.

- **The start's cards are cached under the document, not the version.** A
  composition redrawn without a version bump went on being served from the
  old card in any host with a real cache store — which is what happened to
  the six compositions this release redraws.

### Fixed

- **A composition's bottom arc is set inside its band again.** Ring and
  Medallion asked for `sweep: bottom` with `reversed: true`, which is not the
  form the Stockholm reference uses and does not survive the round trip: the
  named half already carries its own direction, so reversing it a second time
  turned the glyphs' up-direction outward and the type was set outside the
  ring, straddling the edge. Both now name the angles they sweep between, as
  the reference does. Nothing warned about this, on any shape.

### Changed

- **The compositions are drawn as their references draw them.** The arcs stop
  short of the sides, so the two words no longer collide at three and nine
  o'clock, and the Ring's pair — 19 and 12, which the note has always
  promised and which were a double space in the middle of the field — sit in
  the gaps the arcs leave, on a setting line, the way Stockholm Stadion sets
  them. The Medallion's letter has air around it instead of touching the
  inner rule. The Lozenge stack's lines were being clamped to six tenths of
  their width, each by a different amount; they are set at a rate that fits
  the chord they are on. The Shield's two lines leave each other room and its
  inner rule is far enough in to read as a band. The Plate's word is off the
  rule. Wide word is unchanged.

- **Pandatone comes from its default branch, not a tag.** A tag cannot exist
  until the change that needs it has merged, so every cross-repo move cost a
  branch pin, a merge, a tag and a re-pin. This Gemfile is only what the
  dummy runs on; a host resolves the gemspec, which still asks for a version.
  The trade is deliberate: the suite now runs against Pandatone's tip, so a
  break between the two shows up here rather than in a host.

## 0.6.0 — 2026-09-08

On its-swiss 1.0. The core is unchanged and moves with it.

### Changed

- **Set on its-swiss 1.0.** The library registers its own controllers from
  a module its shell imports, so the dummy no longer registers them by hand.
  A form has no width of its own in 1.0, which is what the start had to say
  for itself before; it no longer does.

## 0.5.0 — 2026-09-08

The start, and the document beside the drawing. A new badge began as YAML in a textarea; it now begins as a composition on a shape, and the YAML is the editor's second view of the same document.

### Added

- **The start.** "Compose a badge" is a name, six compositions and a row of shapes. A composition is a real document the core renders (Ring, Medallion, Lozenge stack, Wide word, Shield band, Plate), each with a placeholder word and the reference it is after; its card is the core's own render, so the card cannot drift from the badge. A shape goes under any composition, since regions derive from whatever the container is; a circle takes the composition's longer side so nothing placed inside it falls outside. The button says what the two choices add up to, the name is the composition's until one is typed, and a path shape asks for its data. Composed, the badge opens in the editor on its first run with its text selected, so the first thing done to it is typing its word. "Or paste a document" keeps the YAML field for a document brought from elsewhere. `Badger::Compositions` holds them; the cards are cached per font and version.
- **The Document view.** The editor has two views of one badge, named on one line above it: the drawing, and the document as YAML. What is typed is drawn as it is typed, through `POST /badges/:id/render` with `document_yaml`; a document that does not build is refused under the text, naming where and why, and the drawing keeps the last one that did. A handle moved on the drawing is a number changed in the text. The render's answer carries the document both ways, as JSON and as YAML.

- **One history.** Every change to the document is a step that can be taken back: a field typed, a number scrubbed, a handle dragged, an entry added, removed or hidden, the YAML edited. Undo and Redo are on the views' line, and ⌘Z and ⇧⌘Z everywhere on the page. Delete removes the selection, and the line under the tree says what was removed with an Undo beside it; ⌘S saves.
- **Anything visible can be taken hold of.** A press on a piece of the drawing selects it and a drag moves it by what it is: a run turns round its band, a band moves with its width kept, a rule or an interior moves in or out, a fitted line slides its chord, anything placed moves its point (a thing at the centroid becomes fractions of its parent from where it stands). A piece lifts under the pointer; each handle has a cursor for the way it goes and a tooltip naming its number, and moves with the pointer before the drawing catches up. Distances snap to the unit and angles to 5°, Shift for free; Alt on a sweep's end keeps the sweep symmetrical about the vertical. The wheel pans, Ctrl or ⌘ with it (a trackpad's pinch) zooms about the pointer, Space and a drag pan, and 0, 1 and 2 are the zoom buttons. While the server draws, the stage says so.
- **The inspector is a panel.** Fields are in four groups, the way a designer asks — what the entry is, where it goes, how it is set, how it looks — with the rare ones behind More. Alignment is nine points to click. A sweep is a centre and a span in degrees, with the two angles they come to said underneath. Fractions are percentages. A number can be scrubbed by dragging its label sideways, and nudged by tens with Shift and the arrows. A field that is a handle's number lights the handle when the pointer is over it, and lights up while the handle is held. A warning sits beside the field it is about, and marks the entry's line in the tree. The kind of a region and the mode of a run are changed in the panel's head, not among the numbers; a number typed no longer rebuilds the panel under the typing.
- **The adders say where and what.** "Add to setting line" names the container the new entry goes into, and each adder asks the kind up front: a band, a rule or an interior; a run following a band, a line fitted to a chord, a line at a fixed size. A run added where there is no band brings a band with it. The tree's notes are plain words: "136° about 270° on ring", "the chord at y −311 in field", "24 units, at the centroid".

### Changed

- `POST /badges/:id/render` takes `document_yaml` as well as `document`, and answers with `document` and `yaml` beside the drawing.
- A badge page opened with `?select=` opens the editor on that address.
- The Edit page renames and nothing else: the document is composed on the badge page, as a drawing or as YAML. The head's button says Rename.

## 0.4.0 — 2026-09-08

The editor. Composing a badge was editing YAML in a textarea; it is now the drawing, with the construction lines as the controls.

### Added

- **The editor**, on the badge page's Compose surface: the document as a tree on three fields, the drawing on six, an inspector on three. Select a line of the tree or a piece of the drawing; the construction it was built on comes up in the accent, with handles: the two ends of a run's sweep, the edges of a band, the distance of a rule, the size of a shape, the chord a line was fitted to, the point a child was placed at. The inspector's fields are built from a schema the engine hands over, one field per parameter the core names, in the library's own markup. Every change re-renders through the server; nothing is saved until Save. `+ Region`, `+ Type`, `+ Child` and `+ Artwork` add starters that draw; Duplicate and Remove are with the entry. Construction, reference and grid layers toggle; Fit, 100% and 200% zoom, the wheel zooms about the pointer, a drag on empty ground pans.
- **References.** The photograph a badge is redrawn from goes under the drawing, one per badge, kept in the badge's own table: PNG or JPEG, its size read from its header. Placed by dragging it on the drawing and scaling from its corner, or by numbers, at a strength set on a slider; the reference badges were measured in their photographs' own pixels, so the default is one unit a pixel, centred. The Dress and Export surfaces draw it under the badge too. `POST /badges/:id/reference` puts one on, `PATCH` places it, `DELETE` takes it off, `GET` serves it.
- **Addresses.** Every piece the core renders carries the address of the document entry that made it (`type[0]`, `children[1].regions[0]`), in `Output#pieces`, `to_h` and the SVG's `data-address`. `Output#construction` returns the overlay geometry for the whole tree, visible or not; `Output#warnings` says what went wrong without failing, each about an address. `Container#construction` walks the tree beside `resolve`. `POST /badges/:id/render` answers all of it for a document without saving it; `PATCH /badges/:id` takes the document as JSON.

### Changed

- The badge page's Compose surface is the editor; the slots table and the document as text moved to Export. The Edit page keeps the YAML, for a document written by hand.
- The API's badge JSON carries `address` on each piece, and `construction` and `warnings`; additive, so v1 stays v1.

## 0.3.0 — 2026-09-07

A day of use. The engine on its-swiss 0.9 and Pandatone 0.3; the core is unchanged and moves with it.

### Changed

- **The badge page is three surfaces.** Compose, Dress and Export, named under the title; the drawing and what is true of it stay in the left column, and stay put, while the surface beside them is worked. The colorway the drawing wears travels with the surfaces, and every dressing action returns to Dress wearing it. The files are a surface of their own; taking the badge away is in the head with editing it.
- **Each thing said once.** A slot without a rule is bound to its rank, so the bindings table says only what is bound to something else. The sentence over every table is behind one mark, opened when it is asked for.
- **One red per page.** The chosen filter is in the weight, in ink; the accent is the host's, for where you are on the site.

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
