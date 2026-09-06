# 🦡 Badger

A badge generator. Takes an SVG shape as input and sets type into regions derived from it.

> A tree of containers. Each container derives regions. Each region holds type — fitted, followed, or fixed — anchored by locator plus alignment.

The full design, scope and build order live in [HANDOFF.md](HANDOFF.md). This README tracks what exists.

## Status

| Step | Deliverable | State |
| --- | --- | --- |
| 1 | Arc-length parameterization over ellipse and arbitrary offset paths | done |
| 2 | Follow mode — glyphs on a spine, tangent rotation, track-to-sweep fitting | geometry done; shaping pending the sidecar/FFI decision |
| 3 | Region derivation — offsets, band, interior; per-region visibility | offsets only |
| 4–9 | Fit modes, container tree, union/knockout, color slots, primitives, engine | not started |

The core gem is plain Ruby with no runtime dependencies. Nothing here knows about fonts yet: `Badger::Follow` distributes *advances* (widths) along a spine, and HarfBuzz supplies those advances once the geometry layer is chosen.

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
bundle exec rake test
ruby examples/step1_demo.rb          # writes examples/out/step1.svg
```

## Next

- Decide sidecar (fontTools + uharfbuzz) vs FFI for shaping and outline extraction; the geometry layer above is independent of that choice.
- Robust offsets (self-intersection cleanup) and booleans need Clipper2 or skia-pathops. The polyline offset here is enough for convex-ish containers and the small distances badges use.
- Step 3 proper: band and interior regions, per-region visibility.
