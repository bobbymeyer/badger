# frozen_string_literal: true

# The three reference badges beside their references, at the references'
# own pixel sizes, with a 50% overlay of the render on the image. The stand-in
# fonts are whatever the system has; the geometry is the test.
#
#   ruby examples/acceptance.rb [output.svg]

require "base64"
require_relative "../lib/badger"

include Badger::Geometry

Badger::Fonts.add_directory("/usr/share/fonts")
out = ARGV[0] || File.join(__dir__, "out", "acceptance.svg")
ref_dir = File.expand_path("../test/acceptance/reference", __dir__)

fonts = { "stockholm" => "DejaVuSans", "le_dive" => "DejaVuSans-Bold", "giletti" => "DejaVuSerif-Bold" }
colors = {
  "stockholm" => { ground: "#e8e2d0", ink: "#2a1a10" },
  "le_dive" => { ground: "#d23c2a", ink: "#ffffff" },
  "giletti" => { ground: "#f6f4ee", ink: "#d3261a" }
}
images = { "stockholm" => [888, 1083, 60 + 391, 52 + 476], "le_dive" => [557, 950, 151 + 140.5, 45 + 422], "giletti" => [942, 529, 467.5, 282.5] }
pages = { "stockholm" => "#2b1a10", "le_dive" => "#f4f4f4", "giletti" => "#eeeadb" }

svg = []
x = 0
sheets = {}
%w[stockholm le_dive giletti].each do |name|
  w, h, cx, cy = images[name]
  doc = Badger::References.public_send(name, font: fonts[name])
  output = Badger.render(Badger::Spec.build(doc), world: Affine.translate(cx, cy))
  data = Base64.strict_encode64(File.binread(File.join(ref_dir, "#{name.tr('_', '-')}.jpg")))
  body = output.to_svg(colors: colors[name]).lines[1..-2].join
  # reference, render, overlay
  trio = []
  3.times do |column|
    ox = column * (w + 20)
    trio << %(<g transform="translate(#{ox} 0)">)
    trio << %(<rect width="#{w}" height="#{h}" fill="#{pages[name]}"/>)
    trio << %(<image href="data:image/jpeg;base64,#{data}" width="#{w}" height="#{h}"/>) if column != 1
    trio << (column == 2 ? %(<g opacity="0.55">#{body}</g>) : body) if column != 0
    trio << "</g>"
  end
  sheets[name] = [3 * (w + 20) - 20, h, trio]
  svg << %(<g transform="translate(#{x} 0)">#{trio.join}</g>)
  x += 3 * (w + 20) + 60
end

sheets.each do |name, (w, h, trio)|
  File.write(out.sub(/\.svg\z/, "-#{name}.svg"), <<~SVG)
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w} #{h}" width="#{w}" height="#{h}">
      <rect width="#{w}" height="#{h}" fill="#d9d4c7"/>
      #{trio.join("\n  ")}
    </svg>
  SVG
end

document = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{x} 1083" width="#{x}" height="1083">
    <rect width="#{x}" height="1083" fill="#d9d4c7"/>
    #{svg.join("\n  ")}
  </svg>
SVG
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, document)
puts "wrote #{out} (#{x} x 1083)"
