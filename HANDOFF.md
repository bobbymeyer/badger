# 🦡 Badger — Handoff

**Repo:** https://github.com/bobbymeyer/badger

A badge generator. Takes an SVG shape as input and sets type into regions derived from it.

---

## The rule

> A tree of containers. Each container derives regions. Each region holds type — fitted, followed, or fixed — anchored by locator plus alignment.

Everything Badger does decomposes into that sentence. It is also the scope test: anything that isn't type set into a region derived from a container path belongs in another tool.

## Scope

| In | Out |
| --- | --- |
| Container as SVG path input | Shape authoring or drawing |
| A small set of shape primitives | Boolean intersections between containers |
| Type fitted to, following, or fixed within regions | General layout surface (poster is a separate tool) |
| Illustration elements placed in containers | Node/pen editing of paths |
| An editor whose handles move the document's parameters | A canvas that draws freely |
| Knockout, single offset stroke | Shadow stacks, textures, engraving, envelope warps |
| SVG out, with metadata | Raster effects, blur |

Register note: the target is early-to-mid 20th century modernism — Stockholm Stadion 1912, Giletti, postwar French and Italian label work. Not Etsy-vintage. Ropes, banners, sunbursts and distressing are outside the register even where they're inside the model.

---

## Model

### Containers

A tree. Each node is a container with a path, either an imported SVG or a primitive. Child coordinates are relative to the parent, so the whole badge moves and scales as one object.

Primitives: circle, ellipse, rectangle, lozenge, rounded rect, shield.

A container may be invisible. An invisible container is a construction line — it still derives regions and still anchors children. This is how the setting line in Stockholm works, and it's how a freestanding block of type is expressed: a transparent rectangle.

### Regions

Derived from a single container. Three types, no others:

| Region | Derivation |
| --- | --- |
| Offset | container path offset by distance d, inward or outward — the visible rules |
| Band (annulus) | area between two offsets — where following type sits |
| Interior | what remains inside the innermost offset |

Visibility is per-region, not per-container. One container can produce a visible outer rule, an invisible setting line, and a visible inner rule.

Regions are optional. A container carrying only an illustration derives none.

### Content

A region holds type or an illustration. Type has three modes:

| Mode | Behavior |
| --- | --- |
| Follow | glyphs distributed along a spine derived from the container; rotated to the local tangent |
| Fit | glyph or line geometry scaled to the region |
| Fixed | set at a given size; the region only positions it |

Fit has three policies:

| Policy | Behavior |
| --- | --- |
| Fill | scale to the region — both axes, or width-only |
| Contain | scale up to the region, capped at a maximum |
| Fixed | set size, region positions only |

Fit variants needed by the reference set:

- fit to band width — cap height equals band thickness (Stockholm)
- fit to width at y — line scaled to the container's horizontal chord at that height (Le Dive)
- fit to height at x — glyph scaled to the container's vertical chord at that position (Giletti)

Non-uniform scaling is a named parameter, not a silent default. For type it is a deliberate period compromise and should be range-constrained. For illustration it should be locked off — uniform only.

### Anchoring

Two independent parts. Centering is one combination among many, not a special case.

**Locator** — a point in the parent's space:

| Locator | Params |
| --- | --- |
| Centroid | — |
| Polar | angle, radius |
| Axial | x%, y% of parent bounds |
| On-path | arc length t along the parent's path |

**Alignment** — which of the child's nine reference points lands on the locator.

Both halves are needed. Symmetric pairs anchored to different edges (Pozzillo's `EST. 1989` and `SICILY`) require holding an edge fixed while content grows away from it; center-only alignment shifts the whole lockup on every string-length change.

### Illustration

Same container type, regions unused. Two rules:

- measure ink bounds, not viewBox — imported SVGs carry arbitrary padding
- strip baked fills and assign one color slot; multi-color artwork passes through as-is and will not respond to colorways

An illustration container can still have a spine that type follows (Salt & Sierra's S).

### Resolution order

Outside-in. Parent geometry resolves first; children fit into the result. Containers do not resize to fit their content.

---

## Type engine

| Capability | Notes |
| --- | --- |
| Shaping | HarfBuzz — kerning, ligatures, OpenType features |
| Outline extraction | Bézier contours in font units |
| Tracking | uniform, and the solve variable for track-to-sweep fitting |
| Pair overrides | explicit map — `AV`, `LT`, `TA` are hand-set in real wordmarks |
| Optical spacing | area-based, HTLetterspacer algorithm — reuse from the type revival pipeline |
| Variable axes | set coordinates before outline extraction |
| Line stacking | explicit breaks only; no automatic wrapping or justification |
| Per-line transform | each line carries its own spine — top arcs, middle straight, bottom reverse-arcs |

Two measurement rules:

- **stack on ink bounds, not font metrics.** A caps line carries an empty descender band; an arced line is taller than its baseline implies. Measure after transform.
- **tracking on a curve is angular.** Specify in length units at the set radius and convert internally, or rings at different radii will not agree.

### Union scope

A flag, because the two produce different products:

| Scope | Result |
| --- | --- |
| Per line | each line gets its own outline; touching lines show a seam |
| Whole block | one continuous outline around the stack — the patch look; also resolves collisions from tight leading |

Union the glyph outlines before any offset or boolean operation. Skipping this is the source of nearly every interior seam artifact.

---

## The hard part

**Arc-length parameterization.** Ellipses have no closed-form arc length. Stepping by uniform angle produces visibly wrong spacing near the ends of the major axis — letters bunch where curvature is high. This is why most browser tools support circles only.

Required: a numeric arc-length table with inverse lookup, over both ellipses and offsets of arbitrary imported paths. Small in volume, and it is what separates correct output from broken output.

**Build this first.** If it works the rest is assembly. If it doesn't, nothing above it is salvageable.

Secondary: corners break spines. A glyph straddling a polygon vertex tears. Either fillet the spine before distributing, or forbid glyphs crossing a vertex and break the run there.

---

## Effects budget

| Effect | Operation |
| --- | --- |
| Knockout | type or artwork subtracted from a filled region — Clipper2 difference |
| Offset stroke | single outward offset on the union |
| Clipped noise | one raster layer clipped to the union, optional |

That's the whole budget. Anything more belongs in the register Badger isn't aiming at.

---

## Output contract

Poster and other consumers need more than a flat SVG blob:

| Returned | Purpose |
| --- | --- |
| Geometry (paths) | placement |
| Ink bounds and optical center | grid alignment without eyeballing |
| Container path, separately | knockout against a field, silhouette reuse |
| Anchor points on the container | hanging sibling elements off badge geometry |
| Color slots, unresolved | recolor per consumer colorway |

Colors must not be baked in. Compose in value; apply colorways after — same contract as Stripeclub. A badge with baked fills has to be regenerated for every poster colorway, which makes it an asset rather than a component.

---

## Architecture

Standard family shape:

- **Core gem** — plain Ruby, no server. Geometry, fitting, type setting. Returns SVG.
- **Rails engine** — controllers, routes, views, mounted at `/badger` in the chassis. Depends on `its-swiss` in its own gemspec.
- **Chassis** — mounts it; orchestrates any cross-tool workflow. Badger stays ignorant of siblings.
- **OpenAPI spec on.** Parameters named semantically (`band_width`, `sweep_start`, `tracking_at_radius`), not `param1`.
- **Rails 8 omakase, TDD.**

Public interface only. `Badger.render(...)`, never reaching into internals from a sibling — and Badger never reaches into Pandatone's.

Palette integration follows the Stripeclub pattern: Badger computes what it needs locally from fetched palettes rather than pushing computation into Pandatone.

### Dependencies

Ruby has no mature native library for glyph geometry or path booleans. Expect FFI bindings or a Python sidecar; the sidecar path reuses tooling already in the revival pipeline. The gem's public interface stays Ruby either way.

| Need | Library |
| --- | --- |
| Shaping | [HarfBuzz](https://github.com/harfbuzz/harfbuzz) / [uharfbuzz](https://github.com/harfbuzz/uharfbuzz) |
| Font parsing, outline extraction | [fontTools](https://github.com/fonttools/fonttools) |
| Booleans, offsets, Minkowski | [Clipper2](https://github.com/AngusJohnson/Clipper2) or [skia-pathops](https://github.com/fonttools/skia-pathops) |
| Optical spacing | [HTLetterspacer](https://github.com/huertatipografica/HTLetterspacer) |
| Bézier math reference | [kurbo](https://github.com/linebender/kurbo) |

JS prototype option, if proving the geometry before committing to bindings is worthwhile: [paper.js](https://github.com/paperjs/paper.js) plus [opentype.js](https://github.com/opentypejs/opentype.js) give the whole stack in one process. Wrong language for the family, right language for a spike.

---

## Build order

| Step | Deliverable |
| --- | --- |
| 1 | Arc-length parameterization over ellipse and arbitrary offset paths |
| 2 | Follow mode — glyphs on a spine, tangent rotation, track-to-sweep fitting |
| 3 | Region derivation — offsets, band, interior; per-region visibility |
| 4 | Fit modes — band width, chord at y, chord at x |
| 5 | Container tree, locator plus alignment anchoring |
| 6 | Union scope flag, knockout, offset stroke |
| 7 | Color slots and output metadata |
| 8 | Primitives, illustration containers |
| 9 | Engine, UI on its-swiss, OpenAPI |

**Acceptance test: Stockholm Stadion 1912.** It exercises the elliptical spine, the annulus, cap-height-equals-band-width fitting, and polar-anchored fixed type in a single image. If Badger renders it correctly the model holds.

---

## Adjacent tools

| Tool | Relationship |
| --- | --- |
| Shape node | emits container paths. Parametric — sides, aspect, corner radius, shield curve. Also feeds Stripeclub masks and camelflagger clipping regions |
| Poster | consumes badges as elements. Needs its own scope rule before it starts; "poster" is a general layout surface and will otherwise absorb neighboring tools |
| its-swiss | flat grid and hierarchy work, no geometry. Shares the tracking module with Badger and nothing else |
| Pandatone | colorway source, resolved against Badger's color slots |

---

## Open questions

- Sidecar or FFI for the geometry layer — decide after the step 1 spike
- Whether pair-kerning overrides live in Badger or move into a shared spacing gem alongside its-swiss's tracking
- Multi-container occlusion (subtract-only, stacking order) was deliberately deferred. Keep region derivation per-container rather than global so adding it later is a data change, not a rewrite
