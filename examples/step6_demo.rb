# frozen_string_literal: true

# Step 6: the effects budget.
#   left    a stacked block with union scope :line (seams between touching
#           lines) beside the same block with :block (one outline), each
#           with the single offset stroke
#   middle  the patch: block union, expanded into a plate, type knocked
#           out of it
#   right   knockout on a badge: ring type and a medallion letter cut out
#           of the filled container
#
#   ruby examples/step6_demo.rb [font.ttf] [output.svg]

require_relative "../lib/badger"

include Badger::Geometry

font_path = ARGV[0] || Dir["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"].first
abort "no font found; pass a path" unless font_path
out = ARGV[1] || File.join(__dir__, "out", "step6.svg")
font = Badger::Font.new(font_path)
ink = "#1d2a44"
svg = []
paint = ->(path, fill = ink, extra = "") { svg << %(<path d="#{path.to_d}" fill="#{fill}"#{extra}/>) }

lines = ->(size) { %w[SALT SIERRA].map { |t| Badger::Setting.new(font.shape(t, size: size)) } }

# --- union scope, with the offset stroke ---------------------------------
[[:line, 120], [:block, 330]].each do |scope, x|
  block = Badger::Block.stack(lines.(48), gap: -2, align: :center, union: scope) # tight: the lines touch
  place = Affine.translate(x, 200)
  # per line: each line's stroke sits on top of the line before it, so the
  # seam shows; per block: one ring under all the ink
  block.paths.each do |p|
    paint.(Badger::Effects.offset_stroke(p, 5).transform(place), "#b8452f")
    paint.(p.transform(place))
  end
end

# --- the patch: plate from the block union, type knocked out --------------
block = Badger::Block.stack(lines.(48), gap: 10, align: :center, union: :block)
plate = Badger::Effects.plate(block.paths, 16)
patch = Badger::Effects.knockout(plate, block.path)
paint.(patch.transform(Affine.translate(560, 200)))

# --- knockout on a badge ---------------------------------------------------
badge = Badger::Container.new(Ellipse.new(rx: 150, ry: 105), name: "badge")
band = badge.band(outer: -8, width: 32)
ring = Badger::Fit.new.to_band(font.shape("KNOCKOUT", size: 100), band, inset: 6).run
top = band.baseline(6)
badge.attach(Badger::Follow.new(top, ring, start: top.length / 2, sweep: top.length / 2, align: :justify))
bottom = band.baseline(6, from: :outer).reversed
badge.attach(Badger::Follow.new(bottom, font.shape("1912", size: ring.size), tracking: 10,
                                start: bottom.length / 2, sweep: bottom.length / 2, align: :center))
medallion = Badger::Container.new(Ellipse.circle(44), visible: false)
medallion.attach(Badger::Fit.new.to_chord_at_x(font.shape("B", size: 100), medallion.interior, 0, inset: 6))
badge.place(medallion, at: Badger::Locator.centroid)
badge.rule(-40, weight: 2, visible: true)

world = Affine.translate(450, 410)
resolved = badge.resolve(world: world)
cut = resolved.reject { |r| r.kind == :container }.map(&:path)
paint.(Badger::Effects.knockout(badge.path.transform(world), *cut))

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 600" width="900" height="600">
    <rect width="900" height="600" fill="#e9e3d5"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out}"
