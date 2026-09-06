# frozen_string_literal: true

# Step 5: a badge as a tree. An elliptical badge with ring type, a
# medallion container placed at its centroid with its own rule and a
# fitted letter, a symmetric pair anchored to opposite edges (the Pozzillo
# rule: EST. and SICILY hold their outer edges as they grow), stars on the
# path rotated to its tangent, and a year polar-anchored below. The whole
# tree is then resolved a second time, moved and halved, as one object.
#
#   ruby examples/step5_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step5.svg")
font = Badger::Font.new(font_path)
L = Badger::Locator

# --- the badge, in its own coordinates (centred on the origin) -------------
badge = Badger::Container.new(Ellipse.new(rx: 230, ry: 160), name: "badge")
badge.rule(0, weight: 5, name: "outer rule")
band = badge.band(outer: -8, width: 40, name: "ring")
badge.rule(-50, weight: 2, name: "inner rule")

ring = Badger::Fit.new.to_band(font.shape("SALT & SIERRA", size: 100), band, inset: 7).run
top = band.baseline(7)
badge.attach(Badger::Follow.new(top, ring, start: top.length / 2, sweep: top.length / 2, align: :justify), name: "ring top")
bottom = band.baseline(7, from: :outer).reversed
badge.attach(Badger::Follow.new(bottom, font.shape("CALIFORNIA", size: ring.size), tracking: 6,
                                start: bottom.length / 2, sweep: bottom.length / 2, align: :center), name: "ring bottom")

# a medallion: its own container, its own regions, placed at the centroid
medallion = Badger::Container.new(Ellipse.circle(58), name: "medallion", visible: false)
medallion.rule(0, weight: 3)
letter = Badger::Fit.new.to_chord_at_x(font.shape("S", size: 100), medallion.interior(inside: -6), 0, inset: 8)
medallion.attach(letter, name: "S")
badge.place(medallion, at: L.centroid, align: :center)

# the Pozzillo pair: each anchored to its outer edge, growing inward
pair_size = 15
badge.place(Badger::Setting.new(font.shape("EST.", size: pair_size)),
            at: L.polar(angle: 180, radius: 150), align: :left, name: "est")
badge.place(Badger::Setting.new(font.shape("1989", size: pair_size)),
            at: L.polar(angle: 0, radius: 150), align: :right, name: "year")

# stars on the path, rotated to its tangent, at the left and right ends
star = Path.parse("M 0 -10 L 2.9 -3.1 L 9.5 -3.1 L 4.4 1.2 L 5.9 8.1 L 0 4 L -5.9 8.1 L -4.4 1.2 L -9.5 -3.1 L -2.9 -3.1 Z")
[0.0, 0.5].each do |fraction|
  badge.place(star, at: L.on_path(fraction: fraction), align: :center, rotate: :tangent, name: "star")
end

# a fixed line polar-anchored below the medallion, top edge on the locator
badge.place(Badger::Setting.new(font.shape("SINCE 1989", size: 11)),
            at: L.polar(angle: 90, radius: 66), align: :top, name: "since")

# --- render the tree twice: full size, and moved and halved ---------------
def paint(resolved)
  resolved.map do |r|
    fill = case r.kind
           when :container then "#f4f1ea"
           when :region then "#1d2a44"
           when :type then "#1d2a44"
           when :illustration then "#b8452f"
           end
    stroke = r.kind == :container ? ' stroke="#1d2a44" stroke-width="0.5" stroke-dasharray="3 3"' : ""
    %(<path d="#{r.path.to_d}" fill="#{fill}"#{stroke}/>)
  end
end

svg = paint(badge.resolve(world: Affine.translate(270, 300)))
svg += paint(badge.resolve(world: Affine.translate(720, 300) * Affine.scale(0.5)))

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 600" width="900" height="600">
    <rect width="900" height="600" fill="#e9e3d5"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out}"
