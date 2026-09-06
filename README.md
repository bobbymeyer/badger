# 🦡 Badger

A badge generator. Takes an SVG shape as input and sets type into regions derived from it.

> A tree of containers. Each container derives regions. Each region holds type — fitted, followed, or fixed — anchored by locator plus alignment.

The full design, scope and build order live in [HANDOFF.md](HANDOFF.md). This README tracks what exists.

## Status

| Step | Deliverable | State |
| --- | --- | --- |
| 1 | Arc-length parameterization over ellipse and arbitrary offset paths | done |
| 2 | Follow mode — glyphs on a spine, tangent rotation, track-to-sweep fitting | done |
| 3 | Region derivation — offsets, band, interior; per-region visibility | done |
| 4 | Fit modes — band width, chord at y, chord at x | done |
| 5 | Container tree, locator plus alignment anchoring | done |
| 6 | Union scope flag, knockout, offset stroke | done |
| 7 | Color slots and output metadata | done |
| 8 | Primitives, illustration containers | done |
| 9 | Engine, UI on its-swiss, OpenAPI | done: `engine/` |

The core gem is plain Ruby. Shaping and outline extraction go through a Python sidecar that ships inside the gem (`lib/badger/sidecar/shape.py`): HarfBuzz via uharfbuzz, outlines via fontTools, one JSON request per process. The gem's public interface is Ruby only.

## Sidecar setup

The host provides an interpreter with the packages in `requirements.txt`; the gem provides everything else. Set `BADGER_PYTHON` to pick the interpreter (default `python3`).

```
pip install -r requirements.txt
ruby -Ilib -rbadger -e 'p Badger.doctor'
```

In the chassis Dockerfile, in the base stage before `USER 1000`:

```dockerfile
RUN apt-get update -qq && apt-get install --no-install-recommends -y python3 python3-pip && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN pip3 install --no-cache-dir --break-system-packages -r $(bundle show badger)/requirements.txt
```

`Badger.doctor` reports the interpreter and package versions and whether shaping can run; wire it into a boot check or a rake task in the host.

## What step 2 gives you

```ruby
font = Badger::Font.new("fonts/Some-Bold.ttf")
run  = font.shape("STOCKHOLM STADION", size: 34,
                  features: { liga: false }, variations: { wght: 700 },
                  pair_overrides: { "TA" => -1.5 })
run.advances                                # per glyph, in badge units, kerning applied
run.cap_height                              # scaled metrics
run.path                                    # outlines set straight, y down, pen at origin
run.ink_bounds                              # measure ink, not font metrics

ring = ellipse.spine.offset(-40)
top  = Badger::Follow.new(ring, run, start: ring.length / 2, sweep: ring.length / 2, align: :justify)
top.tracking                                # solved so the run fills the sweep
top.path.to_d                               # glyph outlines on the spine, as SVG path data
```

`examples/step2_demo.rb` sets a Stockholm-style ring with a system font.

## What step 3 gives you

```ruby
badge = Badger::Container.new(ellipse, name: "badge")      # or a Path, or a Spine
badge.rule(0, weight: 5)                                  # visible outer rule
band  = badge.band(outer: -9, width: 44)                  # invisible by default: a setting band
badge.rule(-56, weight: 2)                                # visible inner rule
field = badge.interior(inside: -57, visible: true)

band.baseline(7)                                          # spine 7 units in from the inner edge
band.baseline(7, from: :outer)                            # for reversed type along the bottom
field.chord_at_y(y)                                       # [x0, x1] horizontal chord: fit-to-width-at-y
field.chord_at_x(x)                                       # [y0, y1] vertical chord: fit-to-height-at-x
field.centroid
badge.visible_regions.map(&:path)                         # fill geometry, rings wound for either fill rule
```

Offsets are memoized per container, so a band's inner edge and the rule drawn on it are the same spine. `examples/step3_demo.rb` renders one container with mixed visibility.

## What step 4 gives you

```ruby
fit = Badger::Fit.new(policy: :fill)                     # :fill, :contain (max_size:), or :fixed
fit.to_band(run, band, inset: 6).run                     # cap height equals the band width: Stockholm
fit.to_chord_at_y(run, field, y, edge: :narrowest)       # line scaled to the horizontal chord: Le Dive
fit.to_chord_at_x(run, field, x)                         # glyph scaled to the vertical chord: Giletti
fit.to_box(run, width: w)                                # plain box fit, uniform

Badger::Fit.new(axes: :both, stretch: 0.8..1.25)         # non-uniform, named and range-constrained
   .to_box(run, width: w, height: h)                     # -> Result with scale_x, scale_y, stretch
run.scale_by(k); run.at_size(s)                          # exact rescaling, no sidecar round trip
```

Chord fits return a `Badger::Setting`: the scaled run plus the affine that centres its ink on the chord, with `anchor: :baseline` to put the baseline at y instead. Measurement is on ink bounds, never font metrics; the band fit is the one exception because cap height *is* its definition. The chord fits solve a root rather than iterate, since the chord depends on where the ink lands and the ink depends on the scale. `examples/step4_demo.rb` sets all three reference fits.

## What step 5 gives you

```ruby
L = Badger::Locator
badge.attach(follow, name: "ring")                                   # already in the badge's space
badge.place(medallion, at: L.centroid, align: :center)               # a child container, own regions
badge.place(est, at: L.polar(angle: 180, radius: 150), align: :left) # symmetric pair, each holding
badge.place(year, at: L.polar(angle: 0, radius: 150), align: :right) #   its outer edge as it grows
badge.place(star, at: L.on_path(fraction: 0.5), rotate: :tangent)    # on the path, turned to it
badge.place(caption, at: L.axial(0.5, 0.9), align: :top)             # fractions of the bounds

badge.resolve(world: Affine.translate(x, y) * Affine.scale(0.5))     # outside-in, as one object
   # -> [Resolved(kind:, name:, path:, source:, depth:)] in world coordinates
```

A locator is a point in the parent's space; an alignment is which of the child's nine reference points lands on it. Centering is one combination, not a special case. Children keep their own coordinates and `place` computes the affine into the parent, so nested containers compose and nothing resizes to fit its content. `examples/step5_demo.rb` builds a badge as a tree and resolves it twice.

## What step 6 gives you

```ruby
block = Badger::Block.stack(lines, gap: 10, align: :center, union: :block)  # or :line
block.paths                                            # unioned outlines: one per line, or one for the block
Badger::Effects.offset_stroke(block.paths, 5)          # the single outward offset, as a ring
Badger::Effects.plate(block.paths, 16)                 # the union grown into a patch
Badger::Effects.knockout(field.path, *type_paths)      # type subtracted from a filled region
Badger::Booleans.union(a, b); .difference(a, b); .intersection; .xor; .expand(a, d)
```

Booleans run on skia-pathops through the sidecar (a second op alongside shaping). `Block` is a stack of lines with the union scope flag: per line keeps a seam where lines touch, whole block gives one outline and absorbs collisions from tight leading. `stack` positions lines on ink bounds, never font metrics. The offset is Skia's stroker unioned back into the shape, so holes shrink and concave corners fill correctly, which the polyline offset in the geometry layer does not attempt. That is the whole effects budget. `examples/step6_demo.rb` shows all of it.

## What step 7 gives you

```ruby
output = Badger.render(badge, world: Affine.translate(x, y))   # the public interface
output.pieces          # geometry in world space, each with kind, name and slot rank
output.ink_bounds      # bounds of everything drawn
output.optical_center  # area-weighted centre: not the middle of the bounds on a shield
output.container_path  # the root container's path, separately, for knockouts and silhouettes
output.anchors         # nine reference points and the centroid; output.anchor(locator) for any other
output.slots           # ranks in use, densely numbered, each with a value grey
output.to_svg          # fills are var(--badger-slot-N, <value grey>): unresolved, stands alone
output.to_svg(colors: { ground: "#f4f1ea", ink: "#1d2a44" })   # dressed by a consumer's colorway
output.to_h / to_json  # the metadata
```

Colour is a slot, not a hex. Every piece carries a rank: the container silhouette is the ground, rules and type are ink, a visible band or interior is a field, and any of them can be reassigned with `slot:`. Ranks in use are numbered densely, so a badge that used 0 and 2 has two slots, and an undressed badge renders in the same paper-to-ink value ladder its-swiss and Stripeclub use. Pandatone supplies the colours; the colorway (palette snapshot, per-slot rules, drift) belongs to the engine, and the core gem never sees a palette. `examples/step7_demo.rb` renders one output undressed and in two colorways, with the contract drawn over it.

## What step 8 gives you

```ruby
S = Badger::Shapes                                   # each centred on the origin, or on center:
S.circle(60); S.ellipse(75, 50); S.rectangle(130, 100); S.lozenge(130, 120)
S.rounded_rectangle(130, 100, radius: 22); S.shield(120, 130, shoulder: 0.4, curve: 0.55)

art = Badger::Illustration.from_file("mark.svg")     # paths, rect, circle, ellipse, polygon; groups and transforms
art.bounds                                           # ink bounds, never the viewBox
art.monochrome?                                      # one fill: stripped, takes one slot
art.multicolor?                                      # more than one: passes through as-is, keeps its fills, no slot
art.scale_by(k)                                      # uniform only; Fit refuses axes: :both on artwork
badge.place(art, at: L.centroid, align: :center)     # placed on its ink
art.to_container                                     # its outline as a container: bands, rules, type that follows it
```

The primitives are the whole set the handoff names; anything more parametric is the shape node's job. Illustration parsing is REXML, the gem's one runtime dependency. `examples/step8_demo.rb` shows the six primitives as containers, both kinds of artwork, and type following a leaf.

## The document, and step 9

A badge is a document. `Badger::Spec.build(doc)` turns one into the container tree, with every parameter named for what it means:

```yaml
name: Stockholm Stadion
shape: { kind: ellipse, rx: 260, ry: 170 }
regions:
  - { kind: rule, distance: 0, weight: 5 }
  - { kind: band, name: ring, outer: -8, width: 40 }
  - { kind: rule, distance: -50, weight: 2 }
  - { kind: interior, name: field, inside: -52 }
type:
  - { mode: follow, text: STOCKHOLM STADION, font: Archivo, region: ring, inset: 7, sweep: top, align: justify }
  - { mode: follow, text: "1912", font: Archivo, region: ring, from: outer, inset: 7, sweep: bottom, tracking: 12 }
  - { mode: fit, text: OLYMPIA, font: Archivo, region: field, fit: chord_at_y, at: 0, inset: 24, edge: narrowest }
  - { mode: fixed, text: EST., font: Archivo, size: 14, at: { polar: { angle: 180, radius: 150 } }, align: left }
```

Fonts are named, not pathed: `Badger::Fonts.add_directory(dir)` scans for TrueType, OpenType and woff2 files and a document says `font: Archivo-Bold`. `sweep: top` and `sweep: bottom` find the run from the leftmost to the rightmost point by way of that side on any closed spine, reading left to right.

**The engine** lives in `engine/` as a second gem, `badger-rails`, packaged the way Pandatone and Stripeclub are: its own controllers, routes, views, migrations and stylesheets under the `Badger` namespace and the `badger_` table prefix, inheriting the host's door and shell. It stores badges as documents, renders them in value, dresses them in a Pandatone palette as a colorway (a snapshot plus a rule per slot, drift reported and never applied), and serves a read-only JSON API described at `api/v1/openapi`. The Ruby interface is `Badger.badges`, `Badger.badge(key)`, `Badger.badge_svg(key, colorway:)`, `Badger.colorways`, `Badger.colorway(id)`.

A host takes both gems from one tag, sets `Badger.palette_source` and `Badger.font_directories` in an initializer, mounts `Badger::Engine`, and installs `requirements.txt` into its Python. `bin/rails badger:doctor` says whether the sidecar can run; `bin/rails badger:seed` plants Stockholm, Giletti and Le Dive.

```sh
cd engine && bundle install && bin/rails test   # the engine's suite, against the dummy host under test/
```

## What step 1 gives you

```ruby
require "badger"
include Badger::Geometry

ellipse = Ellipse.new(rx: 260, ry: 170, center: Point.new(400, 300))
spine   = ellipse.spine                     # arc-length addressed, closed
spine.length                                # numeric perimeter, ~1e-12 relative error
spine.point_at(spine.length / 3)            # a point one third of the way round
spine.at(120).tangent                       # unit tangent (reading direction) at arc length 120
spine.at(120).normal                        # unit normal (glyph "up")
spine.sample(48)                            # 48 points at equal arc length

rule   = spine.offset(14)                   # outward offset, round joins at convex corners
band   = spine.offset(-40)                  # inward offset
rule.to_path.to_d                           # SVG path data

shield = Path.parse("M 0 0 L 240 0 L 240 120 C 240 200 160 260 120 280 C 80 260 0 200 0 120 Z")
shield.spine.corners                        # arc lengths where a glyph would tear
```

`Path.parse` handles the whole SVG `d` grammar (absolute and relative; arcs become cubics). Every piece — line, cubic, exact ellipse, polyline offset — goes through the same `ArcLengthTable`: Gauss-Legendre quadrature into a cumulative table, binary search plus Newton polish for the inverse.

`Badger::Follow` places a run of advances on a spine, centred on each advance so the glyph straddles the curve, with `:start`/`:center`/`:end` alignment at a given tracking or `:justify` to solve tracking against the sweep. Runs on closed spines wrap; a placement that spans a corner is flagged. `Badger::Tracking` converts a tracking length at a set radius to other radii so stacked rings agree angularly.

Reversing a spine (`spine.reversed`) is how the bottom arc of a badge reads left to right with glyph tops toward the centre.

## Running

```
bundle install
pip install -r requirements.txt
bundle exec rake test
ruby examples/step1_demo.rb          # writes examples/out/step1.svg
ruby examples/step2_demo.rb          # writes examples/out/step2.svg
ruby examples/step3_demo.rb          # writes examples/out/step3.svg
ruby examples/step4_demo.rb          # writes examples/out/step4.svg
ruby examples/step5_demo.rb          # writes examples/out/step5.svg
ruby examples/step6_demo.rb          # writes examples/out/step6.svg
ruby examples/step7_demo.rb          # writes examples/out/step7.svg and .json
ruby examples/step8_demo.rb          # writes examples/out/step8.svg
```

Tests shape against `test/fixtures/badger-test.ttf`, a 1 KB font with exact known metrics generated by `test/fixtures/build_test_font.py`.

## Next

- The acceptance test proper: Stockholm Stadion 1912 against the reference, once the reference and its font are to hand. The seed is the mechanism, not the result.
- Corners still break spines: a run across a concave vertex tears, as the handoff says. `Follow` flags the placement; filleting the spine or breaking the run there is not built yet.
- Each boolean is a sidecar process today. If badges get interactive, a long-lived worker is a change inside the gem, not the chassis.
- The polyline offset in the geometry layer is enough for region derivation on convex-ish containers; the effects layer offsets through Skia.
- Optical spacing (HTLetterspacer) as a second sidecar op, once the revival pipeline's implementation is available to reuse.
