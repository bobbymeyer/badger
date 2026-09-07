require "yaml"

module Badger
  # A small, real library to look at: the three reference badges. Idempotent:
  # a badge that is already there is left alone. `font:` names a font the
  # host has; the starter document below is what the editor opens with.
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

    # The three reference badges the core is measured against, from
    # Badger::References, in the reference images' own pixels.
    def documents(font)
      References.all(font: font).values
    end
  end
end
