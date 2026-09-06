require "yaml"

module Badger
  # A small, real library to look at. Idempotent: a badge that is already
  # there is left alone. `font:` names a font the host has; the starter
  # document below is what the editor opens with.
  module Seeds
    module_function

    def plant(font: Fonts.names.first)
      raise Badger::Error, "no font to seed with: point Badger.font_directories at some" if font.nil?

      documents(font).each do |doc|
        next if Badge.friendly(doc["name"])

        Badge.create!(name: doc["name"], spec: doc)
      end
    end

    def starter(font:)
      YAML.safe_load(<<~YAML)
        name: New badge
        shape: { kind: ellipse, rx: 220, ry: 150 }
        regions:
          - { kind: rule, distance: 0, weight: 5 }
          - { kind: band, name: ring, outer: -8, width: 40 }
          - { kind: rule, distance: -50, weight: 2 }
          - { kind: interior, name: field, inside: -52 }
        type:
          - { mode: follow, text: BADGE, font: #{font}, region: ring, inset: 7, sweep: top, align: justify }
          - { mode: follow, text: "1912", font: #{font}, region: ring, from: outer, inset: 7, sweep: bottom, tracking: 10 }
          - { mode: fit, text: B, font: #{font}, region: field, fit: chord_at_x, at: 0, inset: 30 }
      YAML
    end

    def documents(font)
      [
        YAML.safe_load(<<~YAML),
          name: Stockholm Stadion
          shape: { kind: ellipse, rx: 260, ry: 170 }
          regions:
            - { kind: rule, name: outer, distance: 0, weight: 5 }
            - { kind: band, name: ring, outer: -8, width: 40 }
            - { kind: rule, name: inner, distance: -50, weight: 2 }
            - { kind: interior, name: field, inside: -52 }
          type:
            - { mode: follow, text: STOCKHOLM STADION, font: #{font}, region: ring, inset: 7, sweep: top, align: justify }
            - { mode: follow, text: "1912", font: #{font}, region: ring, from: outer, inset: 7, sweep: bottom, tracking: 12 }
            - { mode: fit, text: OLYMPIA, font: #{font}, region: field, fit: chord_at_y, at: 0, inset: 84, edge: narrowest }
            - { mode: fixed, text: EST., font: #{font}, size: 14, at: { polar: { angle: 180, radius: 168 } }, align: left }
            - { mode: fixed, text: SWE, font: #{font}, size: 14, at: { polar: { angle: 0, radius: 168 } }, align: right }
        YAML
        YAML.safe_load(<<~YAML),
          name: Giletti
          shape: { kind: rounded_rectangle, width: 260, height: 260, radius: 24 }
          regions:
            - { kind: rule, distance: 0, weight: 4 }
            - { kind: interior, name: field, inside: -14 }
          type:
            - { mode: fit, text: G, font: #{font}, region: field, fit: chord_at_x, at: 0, inset: 10 }
            - { mode: fit, text: GILETTI, font: #{font}, fit: box, width: 150, height: 22, axes: both,
                stretch: { min: 0.8, max: 1.25 }, at: { axial: [0.5, 0.94] }, align: bottom }
        YAML
        YAML.safe_load(<<~YAML)
          name: Le Dive
          shape: { kind: circle, radius: 150 }
          regions:
            - { kind: rule, distance: 0, weight: 4 }
            - { kind: interior, name: field, inside: -12 }
          type:
            - { mode: fit, text: LE, font: #{font}, region: field, fit: chord_at_y, at: -78, inset: 8, edge: narrowest }
            - { mode: fit, text: DIVE, font: #{font}, region: field, fit: chord_at_y, at: -12, inset: 8, edge: narrowest }
            - { mode: fit, text: CAFÉ, font: #{font}, region: field, fit: chord_at_y, at: 50, inset: 8, edge: narrowest }
            - { mode: fit, text: BAR, font: #{font}, region: field, fit: chord_at_y, at: 100, inset: 8, edge: narrowest }
        YAML
      ]
    end
  end
end
