# frozen_string_literal: true

# Renders the step 1 spike to SVG: arc-length spacing on an ellipse versus
# uniform-angle spacing, offset rings, and runs of placeholder "glyphs"
# (boxes with varying advances) following the top and bottom of the ring
# and an imported SVG path.
#
#   ruby examples/step1_demo.rb [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

out = ARGV[0] || File.join(__dir__, "out", "step1.svg")
svg = []
f = Badger::Geometry.method(:fmt)

def boxes(follow, height, fill)
  follow.placements.map do |p|
    stroke = p.straddles_corner? ? ' stroke="#d33" stroke-width="2"' : ""
    %(<rect x="0" y="#{-height}" width="#{Badger::Geometry.fmt(p.advance)}" height="#{height}" ) +
      %(fill="#{fill}"#{stroke} transform="#{p.svg_transform}"/>)
  end
end

def dots(points, r, fill)
  points.map { |p| %(<circle cx="#{Badger::Geometry.fmt(p.x)}" cy="#{Badger::Geometry.fmt(p.y)}" r="#{r}" fill="#{fill}"/>) }
end

advances = [34, 26, 30, 22, 36, 28, 24, 32, 26, 30, 28, 34]

# --- Panel 1: elliptical ring -------------------------------------------
ellipse = Ellipse.new(rx: 260, ry: 170, center: Point.new(400, 300))
spine = ellipse.spine
outer = spine.offset(14, tolerance: 0.05)
inner = spine.offset(-40, tolerance: 0.05)
setting_top = spine.offset(-26, tolerance: 0.05)

svg << %(<g fill="none" stroke="#222" stroke-width="1.5">)
svg << %(<path d="#{outer.to_path.to_d}"/>)
svg << %(<path d="#{inner.to_path.to_d}"/>)
svg << %(<path d="#{spine.to_path.to_d}" stroke="#bbb" stroke-dasharray="4 4" stroke-width="1"/>)
svg << %(<path d="#{setting_top.to_path.to_d}" stroke="#bbb" stroke-dasharray="4 4" stroke-width="1"/>)
svg << "</g>"

# equal arc length on the outer rule (dark) vs equal parametric angle on the inner rule (red)
svg.concat dots(outer.sample(56), 3, "#222")
angle_inner = Ellipse.new(rx: 220, ry: 130, center: ellipse.center)
svg.concat dots(Array.new(56) { |i| angle_inner.point(i / 56.0) }, 3, "#d33")

# top arc: left end over the top to the right end, reading left to right
top_start = setting_top.length / 2
top = Badger::Follow.new(setting_top, advances, start: top_start, sweep: setting_top.length / 2, align: :justify)
svg.concat boxes(top, 22, "#2a5")

# bottom arc: reversed spine so the run reads left to right along the bottom
bottom_spine = setting_top.reversed
bottom = Badger::Follow.new(bottom_spine, advances.first(9), tracking: 12,
                            start: bottom_spine.length / 2, sweep: bottom_spine.length / 2, align: :center)
svg.concat boxes(bottom, 22, "#36c")

# --- Panel 2: imported SVG path (a shield with cubics and one arc) --------
shield_d = "M 0 0 L 240 0 L 240 120 C 240 200 160 260 120 280 C 80 260 0 200 0 120 Z"
shield = Path.parse(shield_d).spine
shield_offset = shield.offset(18, tolerance: 0.05)
svg << %(<g transform="translate(720 140)">)
svg << %(<path d="#{shield.to_path.to_d}" fill="none" stroke="#222" stroke-width="1.5"/>)
svg << %(<path d="#{shield_offset.to_path.to_d}" fill="none" stroke="#222" stroke-width="1.5"/>)
svg.concat dots(shield_offset.sample(40), 3, "#222")
run = Badger::Follow.new(shield_offset, advances.first(8), tracking: 8, start: 260, align: :start)
svg.concat boxes(run, 18, "#2a5")
around_corner = Badger::Follow.new(shield_offset, [30, 30, 30], tracking: 4, start: shield_offset.length - 45)
svg.concat boxes(around_corner, 18, "#e94")
svg << "</g>"

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 620" width="1040" height="620">
    <rect width="1040" height="620" fill="#f4f1ea"/>
    #{svg.join("\n  ")}
    <text x="20" y="600" font-family="sans-serif" font-size="12" fill="#444">black dots: equal arc length on the offset ring - red dots: equal parametric angle - green/blue: advances following the spine (justified / centred) - orange: a run crossing a corner, flagged red</text>
  </svg>
SVG

Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out}"
