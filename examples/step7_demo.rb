# frozen_string_literal: true

# Step 7: the output contract. One badge rendered three ways from a single
# Output: undressed in the value ladder (fills are custom properties over
# value greys), then dressed with two colour maps a consumer would resolve
# from a palette. The container path, ink bounds, optical centre and
# anchors are drawn over the first.
#
#   ruby examples/step7_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step7.svg")
font = Badger::Font.new(font_path)
L = Badger::Locator

shield = Badger::Container.new(Path.parse("M -110 -120 L 110 -120 L 110 20 C 110 80 50 120 0 140 C -50 120 -110 80 -110 20 Z"),
                               name: "shield")
shield.rule(0, weight: 5, name: "outer rule")
band = shield.band(outer: -9, width: 36, visible: true, name: "band")
shield.rule(-45, weight: 2, name: "inner rule")
field = shield.interior(inside: -46, visible: false)

ring = Badger::Fit.new.to_band(font.shape("OUTPUT CONTRACT", size: 100), band, inset: 7).run
baseline = band.baseline(7)
top_edge = baseline.corners[1] || baseline.length / 3
# contain: as large as the band allows, but no wider than the straight top edge
ring = Badger::Fit.new(policy: :contain, max_size: ring.size).to_box(ring, width: top_edge * 0.94).run
shield.attach(Badger::Follow.new(baseline, ring, start: 0, sweep: top_edge, align: :center), name: "title")

letter = Badger::Fit.new.to_chord_at_x(font.shape("7", size: 100), field, 0, inset: 36)
shield.attach(letter, name: "seven")
# the field narrows toward the point, so the date is fitted to its chord there
date = Badger::Fit.new(policy: :contain, max_size: 14).to_chord_at_y(font.shape("EST. 1912", size: 100), field, 72,
                                                                      inset: 10, edge: :narrowest)
shield.attach(date, name: "est")

output = Badger.render(shield, world: Affine.translate(160, 180))
svg = [output.to_svg.lines[1..-2].join]

# the contract, drawn: container path, ink bounds, optical centre, anchors
min, max = output.ink_bounds
svg << %(<path d="#{output.container_path.to_d}" fill="none" stroke="#b8452f" stroke-width="1" stroke-dasharray="4 3"/>)
svg << %(<rect x="#{min.x}" y="#{min.y}" width="#{output.width}" height="#{output.height}" fill="none" stroke="#2a7" stroke-width="1"/>)
c = output.optical_center
svg << %(<circle cx="#{c.x}" cy="#{c.y}" r="5" fill="#b8452f"/>)
mid = (min + max) / 2
svg << %(<circle cx="#{mid.x}" cy="#{mid.y}" r="3" fill="none" stroke="#2a7"/>)
output.anchors.each_value { |p| svg << %(<circle cx="#{p.x}" cy="#{p.y}" r="2.5" fill="#2a7"/>) }

# dressed, twice, by shifting the same pieces and resolving the slots
colorways = [
  { ground: "#f4f1ea", field: "#c9d6ea", ink: "#1d2a44" },
  { ground: "#1d2a44", field: "#b8452f", ink: "#f4f1ea" }
]
colorways.each_with_index do |colors, i|
  dressed = Badger.render(shield, world: Affine.translate(450 + i * 260, 180))
  svg << dressed.to_svg(colors: colors).lines[1..-2].join
end

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 400" width="900" height="400">
    <rect width="900" height="400" fill="#e9e3d5"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
File.write(out.sub(".svg", ".json"), output.to_json)
puts "wrote #{out}"
