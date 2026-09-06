# frozen_string_literal: true

# Step 3: regions derived from one container, with per-region visibility.
# A visible outer rule, an invisible band whose baseline carries type, a
# visible inner rule, a filled interior, and the interior's chords at a
# few heights (what fit-to-width-at-y will use).
#
#   ruby examples/step3_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step3.svg")
font = Badger::Font.new(font_path)

# Left: an ellipse container. Right: an imported shield path.
badges = []

ellipse = Badger::Container.new(Ellipse.new(rx: 220, ry: 150, center: Point.new(260, 300)), name: "ellipse")
ellipse.rule(0, weight: 5, name: "outer rule")
band = ellipse.band(outer: -9, width: 44, name: "setting band") # invisible
ellipse.rule(-56, weight: 2, name: "inner rule")
interior = ellipse.interior(inside: -57, visible: true, name: "field")
badges << [ellipse, band, interior]

shield_d = "M 0 0 L 300 0 L 300 150 C 300 250 200 320 150 350 C 100 320 0 250 0 150 Z"
shield = Badger::Container.new(Path.parse(shield_d).spine.offset(0).to_path.transform(Affine.translate(560, 120)), name: "shield")
shield.rule(0, weight: 5)
sband = shield.band(outer: -9, width: 40, visible: true) # visible band, filled
shield.rule(-52, weight: 2)
sinterior = shield.interior(inside: -53)
badges << [shield, sband, sinterior]

svg = []
badges.each do |container, band_region, interior_region|
  container.regions.each do |region|
    next unless region.visible?

    fill = region.is_a?(Badger::Regions::Interior) ? "#e8dfc8" : "#1d2a44"
    fill = "#c9d6ea" if region.is_a?(Badger::Regions::Band)
    svg << %(<path d="#{region.path.to_d}" fill="#{fill}"/>)
  end

  size = (band_region.width - 14) / (font.shape("H", size: 100).cap_height / 100.0)
  baseline = band_region.baseline(7)
  run = font.shape(container.name.upcase + " CONTAINER", size: size)
  # the ellipse reads over its top half; the shield's baseline starts at its
  # top-left corner, so its top edge is the first straight stretch
  start, sweep = container.name == "shield" ? [0, baseline.corners[1] || 268] : [baseline.length / 2, baseline.length / 2]
  # a preview of step 4's fill policy: shrink the size until the run fits the sweep
  run = font.shape(run.text, size: size * sweep / run.width * 0.92) if run.width > sweep
  top = Badger::Follow.new(baseline, run, start: start, sweep: sweep, align: :justify)
  svg << %(<path d="#{top.path.to_d}" fill="#1d2a44"/>)

  # chords of the interior at three heights, and the centroid
  c = interior_region.centroid
  [-60, 0, 60].each do |dy|
    chord = interior_region.chord_at_y(c.y + dy)
    next unless chord

    svg << %(<line x1="#{chord[0]}" y1="#{c.y + dy}" x2="#{chord[1]}" y2="#{c.y + dy}" stroke="#d33" stroke-width="1.5"/>)
  end
  chord = interior_region.chord_at_x(c.x)
  svg << %(<line x1="#{c.x}" y1="#{chord[0]}" x2="#{c.x}" y2="#{chord[1]}" stroke="#d33" stroke-width="1.5" stroke-dasharray="4 3"/>)
  svg << %(<circle cx="#{c.x}" cy="#{c.y}" r="4" fill="#d33"/>)
end

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 600" width="900" height="600">
    <rect width="900" height="600" fill="#f4f1ea"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out}"
