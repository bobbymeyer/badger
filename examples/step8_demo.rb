# frozen_string_literal: true

# Step 8: the primitives and illustration containers.
#   top row     the six primitives as containers, each with a rule and a band
#   bottom left a monochrome illustration placed by its ink bounds (the SVG
#               has heavy viewBox padding), taking the ink slot; multi-colour
#               artwork beside it passing through with its own fills
#   bottom right an illustration (a leaf) as a container: type following
#               its outline, the way Salt & Sierra's type follows its S
#
#   ruby examples/step8_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step8.svg")
font = Badger::Font.new(font_path)
S = Badger::Shapes
L = Badger::Locator
colors = { ground: "#f4f1ea", field: "#c9d6ea", ink: "#1d2a44" }
svg = []

primitives = {
  "CIRCLE" => S.circle(60), "ELLIPSE" => S.ellipse(75, 50), "RECTANGLE" => S.rectangle(130, 100),
  "LOZENGE" => S.lozenge(130, 120), "ROUNDED" => S.rounded_rectangle(130, 100, radius: 22), "SHIELD" => S.shield(120, 130)
}
primitives.each_with_index do |(label, shape), i|
  badge = Badger::Container.new(shape, name: label.downcase)
  badge.rule(0, weight: 3)
  band = badge.band(outer: -5, width: 18, visible: true)
  badge.rule(-23, weight: 1.5)
  caption = Badger::Fit.new(policy: :contain, max_size: 13).to_chord_at_y(font.shape(label, size: 100), badge.interior(inside: -24), 0,
                                                                         inset: 6, edge: :narrowest)
  badge.attach(caption)
  svg << Badger.render(badge, world: Affine.translate(85 + i * 145, 90)).to_svg(colors: colors).lines[1..-2].join
end

# monochrome artwork: placed on its ink, not its padded viewBox
star = Badger::Illustration.from_file(File.expand_path("../test/fixtures/mono.svg", __dir__), name: "star")
plate = Badger::Container.new(S.rounded_rectangle(150, 150, radius: 16), name: "plate")
plate.rule(0, weight: 3)
fitted = Badger::Fit.new(policy: :contain, max_size: 1).to_box(star, width: 100, height: 100).run
plate.place(fitted, at: L.centroid, align: :center, name: "star")
svg << Badger.render(plate, world: Affine.translate(110, 310)).to_svg(colors: colors).lines[1..-2].join

# multi-colour artwork: passes through, keeps its fills, takes no slot
multi = Badger::Illustration.from_file(File.expand_path("../test/fixtures/multi.svg", __dir__))
plate2 = Badger::Container.new(S.rounded_rectangle(150, 150, radius: 16), name: "plate")
plate2.rule(0, weight: 3)
plate2.place(multi.scale_by(1.3), at: L.centroid, align: :center, name: "artwork")
svg << Badger.render(plate2, world: Affine.translate(290, 310)).to_svg(colors: colors).lines[1..-2].join

# the illustration as a container: its outline is a spine type can follow.
# The leaf's path starts at one tip and its first curve is the upper edge,
# so the run sits centred on the first half of the offset spine.
leaf = Badger::Illustration.from_file(File.join(__dir__, "leaf.svg"), name: "leaf").scale_by(1.4)
holder = leaf.to_container(name: "leaf container")
ring = holder.band(outer: 30, width: 20)
run = Badger::Fit.new.to_band(font.shape("FOLLOW THE LEAF", size: 100), ring, inset: 5).run
baseline = ring.baseline(5)
holder.attach(Badger::Follow.new(baseline, run, start: 0, sweep: baseline.length / 2, align: :center))
holder.rule(30, weight: 1.5)
holder.rule(50, weight: 1.5)
svg << Badger.render(holder, world: Affine.translate(480, 230)).to_svg(colors: colors).lines[1..-2].join

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 440" width="900" height="440">
    <rect width="900" height="440" fill="#e9e3d5"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out}"
