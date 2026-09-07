require "test_helper"

module Badger
  # The compositions a badge starts from: each a document the core draws,
  # on its own shape and on any other.
  class CompositionsTest < ActiveSupport::TestCase
    test "every composition draws on its own shape without a warning" do
      Compositions.all.each do |composition|
        document = Compositions.document(composition.key, font: FONT)
        assert_equal composition.shape, document.dig("shape", "kind")
        output = Badge.new(name: composition.name, spec: document).output
        assert_operator output.pieces.size, :>, 1, "#{composition.name} draws"
        assert_empty output.warnings, "#{composition.name} warns: #{output.warnings.inspect}"
      end
    end

    test "a composition takes any shape at its own frame" do
      Compositions::SHAPES.each_key do |kind|
        next if kind == "path"

        document = Compositions.document("ring", font: FONT, shape: kind)
        assert_equal kind, document.dig("shape", "kind")
        assert_nothing_raised { Badge.new(name: "Ring", spec: document).output }
      end
      document = Compositions.document("ring", font: FONT, shape: "path", path: "M -200 -240 L 200 -240 L 200 240 L -200 240 Z")
      assert_equal "path", document.dig("shape", "kind")
    end

    test "a path shape without its data, and a shape or composition that is not one, are refused" do
      assert_raises(Badger::Error) { Compositions.document("ring", font: FONT, shape: "path") }
      assert_raises(Badger::Error) { Compositions.document("ring", font: FONT, shape: "blob") }
      assert_raises(Badger::Error) { Compositions.document("nothing", font: FONT) }
    end

    test "the shapes are the core's and the frame decides their size" do
      assert_equal({ "kind" => "circle", "radius" => 240 }, Compositions.shape_for("circle", [ 400, 480 ]))
      assert_equal 2.2, Compositions.shape_for("superellipse", [ 400, 480 ])["exponent"]
      assert_equal 50, Compositions.shape_for("rounded_rectangle", [ 560, 400 ])["radius"]
    end
  end
end
