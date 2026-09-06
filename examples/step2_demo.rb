# frozen_string_literal: true

# Step 2: real type following an elliptical ring through the sidecar.
# Top arc justified across the sweep, bottom arc reversed and centred,
# a straight run on a construction line, and a hand-set pair override.
#
#   ruby examples/step2_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step2.svg")

font = Badger::Font.new(font_path)
ellipse = Ellipse.new(rx: 300, ry: 190, center: Point.new(400, 300))
spine = ellipse.spine
outer = spine.offset(10, tolerance: 0.05)
band_width = 46
inner = spine.offset(-band_width, tolerance: 0.05)

# cap height equals the band width minus a margin: the Stockholm rule
size = (band_width - 12) / (font.shape("H", size: 100).cap_height / 100.0)
baseline = spine.offset(-(band_width - 6), tolerance: 0.05)

top = Badger::Follow.new(baseline, font.shape("STOCKHOLM STADION", size: size, pair_overrides: { "TA" => -1.5 }),
                         start: baseline.length / 2, sweep: baseline.length / 2, align: :justify)

bottom_spine = spine.offset(-6, tolerance: 0.05).reversed
bottom = Badger::Follow.new(bottom_spine, font.shape("1912", size: size), tracking: 14,
                            start: bottom_spine.length / 2, sweep: bottom_spine.length / 2, align: :center)

# a freestanding line on an invisible construction line through the centre
setting_line = Path.polyline([Point.new(250, 312), Point.new(550, 312)]).spine
middle = Badger::Follow.new(setting_line, font.shape("OLYMPIA", size: 52), align: :center)

paths = [top, bottom, middle].map(&:path)
svg = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" width="800" height="600">
    <rect width="800" height="600" fill="#f4f1ea"/>
    <g fill="none" stroke="#1d2a44" stroke-width="3">
      <path d="#{outer.to_path.to_d}"/>
      <path d="#{inner.to_path.to_d}"/>
    </g>
    <path d="#{baseline.to_path.to_d}" fill="none" stroke="#bbb" stroke-width="0.5" stroke-dasharray="3 3"/>
    <g fill="#1d2a44">
      #{paths.map { |p| %(<path d="#{p.to_d}"/>) }.join("\n    ")}
    </g>
  </svg>
SVG

Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, svg)
puts "wrote #{out} using #{File.basename(font_path)}; sidecar calls: 5; top tracking #{top.tracking.round(2)}"
