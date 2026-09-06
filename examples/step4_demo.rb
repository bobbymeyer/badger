# frozen_string_literal: true

# Step 4: the three fits the reference set needs.
#   left    Stockholm: cap height equals band width, then followed
#   middle  Le Dive: stacked lines, each scaled to the interior's chord at its height
#   right   Giletti: one glyph scaled to the vertical chord at its x
#
#   ruby examples/step4_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step4.svg")
font = Badger::Font.new(font_path)
ink = "#1d2a44"
svg = []
paint = ->(path, fill = ink) { svg << %(<path d="#{path.to_d}" fill="#{fill}"/>) }

# --- Stockholm: fit to band ------------------------------------------------
stockholm = Badger::Container.new(Ellipse.new(rx: 150, ry: 105, center: Point.new(170, 300)))
stockholm.rule(0, weight: 4)
band = stockholm.band(outer: -7, width: 34)
stockholm.rule(-44, weight: 2)

fitted = Badger::Fit.new.to_band(font.shape("STOCKHOLM STADION", size: 100), band, inset: 6).run
baseline = band.baseline(6)
paint.(Badger::Follow.new(baseline, fitted, start: baseline.length / 2, sweep: baseline.length / 2, align: :justify).path)
bottom = band.baseline(6, from: :outer).reversed
paint.(Badger::Follow.new(bottom, fitted.at_size(fitted.size).then { font.shape("1912", size: fitted.size) },
                          tracking: 10, start: bottom.length / 2, sweep: bottom.length / 2, align: :center).path)

# --- Le Dive: fit to width at y -------------------------------------------
dive = Badger::Container.new(Ellipse.circle(120, center: Point.new(450, 300)))
dive.rule(0, weight: 4)
field = dive.interior(inside: -12)
lines = [["LE", 226], ["DIVE", 288], ["CAFÉ", 344], ["BAR", 392]]
lines.each do |text, y|
  setting = Badger::Fit.new.to_chord_at_y(font.shape(text, size: 100), field, y, inset: 8, edge: :narrowest)
  paint.(setting.path)
end

# --- Giletti: fit to height at x ------------------------------------------
giletti = Badger::Container.new(Path.rect(640, 190, 220, 220).spine.offset(0).to_path)
giletti.rule(0, weight: 4)
gfield = giletti.interior(inside: -14)
big = Badger::Fit.new.to_chord_at_x(font.shape("G", size: 100), gfield, 750, inset: 10)
paint.(big.path)
# a caption fitted to the width at a height, non-uniformly, within the period range
caption = Badger::Fit.new(axes: :both, stretch: 0.8..1.25).to_box(font.shape("GILETTI", size: 100), width: 150, height: 22)
cap = Badger::Setting.new(caption.run, Affine.translate(0, 0) * Affine.scale(1, caption.stretch))
min, max = cap.ink_bounds
paint.(cap.transform(Affine.translate(750 - (min.x + max.x) / 2, 460 - max.y)).path)

[stockholm, dive, giletti].each { |c| c.visible_regions.each { |r| paint.(r.path) } }

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 600" width="900" height="600">
    <rect width="900" height="600" fill="#f4f1ea"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out}"
