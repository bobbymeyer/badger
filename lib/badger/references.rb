# frozen_string_literal: true

require "yaml"

module Badger
  # The three reference badges the handoff measures the model against, as
  # documents, in the reference images' own pixels. Each names the
  # capability it exists to prove.
  #
  # Every number here was measured off the reference: see
  # test/acceptance/reference/ and the acceptance tests beside it.
  module References
    module_function

    def all(font:) = { "stockholm" => stockholm(font: font), "le_dive" => le_dive(font: font), "giletti" => giletti(font: font) }

    # A ring: the container knocked out to its band. STOCKHOLM over the top
    # and STADION reversed along the bottom, each justified between polar
    # angles, at cap height equal to the band less an inset; 19 and 12
    # upright on an invisible setting line through the middle. The oval is
    # squarer than an ellipse: a superellipse.
    def stockholm(font:, serif_font: nil)
      YAML.safe_load(<<~YAML)
        name: Stockholm Stadion
        shape: { kind: superellipse, width: 782, height: 952, exponent: 2.2 }
        visible: false
        regions:
          - { kind: band, name: ring, outer: 0, width: 153, visible: true, slot: ground }
        type:
          - { mode: follow, text: STOCKHOLM, font: #{font}, region: ring, inset: 12,
              sweep: { from: 202, to: 338 }, align: justify, name: top }
          - { mode: follow, text: STADION, font: #{font}, region: ring, from: outer, inset: 12,
              reversed: true, sweep: { from: 170, to: 10 }, align: justify, name: bottom }
        children:
          - name: setting line
            shape: { kind: rectangle, width: 782, height: 1 }
            visible: false
            at: centroid
            type:
              - { mode: fit, fit: box, height: 119, axes: height, text: "19", font: #{font},
                  at: { axial: [0.098, 0.5] }, align: center, name: "19" }
              - { mode: fit, fit: box, height: 119, axes: height, text: "12", font: #{font},
                  at: { axial: [0.902, 0.5] }, align: center, name: "12" }
      YAML
    end

    # A tall lozenge with rounded points. Every line is fitted to half the
    # chord at its own height with its height fixed, so widths stretch to
    # the shape within a range and the I stays a bar.
    def le_dive(font:)
      # text, y, height, and the stretch range: the I keeps its natural width
      lines = [["LE", -311, 45, 0.6], ["D", -190, 105, 0.6], ["I", -58, 105, 1.0], ["V", 53, 105, 0.6], ["E", 184, 105, 0.6], ["37", 309, 43, 0.6]]
      YAML.safe_load(<<~YAML)
        name: Le Dive
        shape: { kind: lozenge, width: 281, height: 974, radius: 25 }
        regions:
          - { kind: interior, name: field, inside: -14 }
        type:
        #{lines.map { |text, y, height, min| "  - { mode: fit, fit: chord_at_y, text: \"#{text}\", font: #{font}, region: field, at: #{y}, height: #{height}, fill: 0.5, stretch: { min: #{min}, max: 2.2 }, name: \"#{text}\" }" }.join("\n")}
      YAML
    end

    # A wide lozenge with an inset hairline rule. The word takes one width
    # scale across the middle; each glyph's height is the vertical chord at
    # its own x, within a range, so the E in the middle is tallest.
    def giletti(font:)
      YAML.safe_load(<<~YAML)
        name: Giletti
        shape: { kind: lozenge, width: 811, height: 353 }
        regions:
          - { kind: rule, name: rule, distance: -13, weight: 2 }
          - { kind: interior, name: field, inside: -14 }
        type:
          - { mode: fit, fit: chord_at_x_per_glyph, text: GILETTI, font: #{font}, region: field, at: 0,
              fill: 0.67, inset: 12, tracking: 11, edge: narrowest, stretch: { min: 0.6, max: 2.3 }, name: GILETTI }
      YAML
    end
  end
end
