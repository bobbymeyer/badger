# frozen_string_literal: true

require "test_helper"
require "yaml"

class FontsTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def setup = Badger::Fonts.reset!
  def teardown = Badger::Fonts.reset!

  def test_scans_directories_and_names_fonts_by_file_name
    Badger::Fonts.add_directory(FIXTURES)
    assert_equal ["badger-test"], Badger::Fonts.names
    assert_equal File.join(FIXTURES, "badger-test.ttf"), Badger::Fonts.path_for("badger-test")
    assert_kind_of Badger::Font, Badger::Fonts.font("badger-test")
    assert_same Badger::Fonts.font("badger-test"), Badger::Fonts.font(:"badger-test")
  end

  def test_explicit_registration_and_paths
    Badger::Fonts.register("Test", File.join(FIXTURES, "badger-test.ttf"))
    assert_equal ["Test"], Badger::Fonts.names
    assert_equal File.join(FIXTURES, "badger-test.ttf"), Badger::Fonts.path_for(File.join(FIXTURES, "badger-test.ttf"))
  end

  def test_unknown_font_names_what_is_known
    Badger::Fonts.add_directory(FIXTURES)
    error = assert_raises(Badger::Fonts::Unknown) { Badger::Fonts.font("Nope") }
    assert_match(/known: badger-test/, error.message)
  end
end

class SweepTest < Minitest::Test
  include Badger::Geometry

  def test_top_and_bottom_of_an_ellipse
    spine = Ellipse.new(rx: 200, ry: 100).spine
    top = spine.sweep(:top)
    assert_same spine, top.spine
    assert_in_delta spine.length / 2, top.start, 1
    assert_in_delta spine.length / 2, top.length, 1
    assert_operator top.spine.point_at(top.start + top.length / 2).y, :<, 0
    bottom = spine.sweep(:bottom)
    refute_same spine, bottom.spine
    assert_operator bottom.spine.point_at(bottom.start + bottom.length / 2).y, :>, 0
    assert_operator bottom.spine.point_at(bottom.start).x, :<, 0, "reads left to right"
  end

  def test_top_and_bottom_edges_of_a_rectangle_and_a_shield
    rect = Badger::Shapes.rectangle(200, 100).spine
    top = rect.sweep(:top)
    assert_point pt(-100, -50), top.spine.point_at(top.start)
    assert_point pt(100, -50), top.spine.point_at(top.end)
    bottom = rect.sweep(:bottom)
    assert_point pt(-100, 50), bottom.spine.point_at(bottom.start)
    assert_point pt(100, 50), bottom.spine.point_at(bottom.end)
    shield = Badger::Shapes.shield(200, 260).spine.sweep(:top)
    assert_in_delta 200, shield.length, 1
  end

  def test_validation
    assert_raises(ArgumentError) { Ellipse.circle(1).spine.sweep(:left) }
    assert_raises(ArgumentError) { Path.polyline([pt(0, 0), pt(1, 0)]).spine.sweep(:top) }
  end
end

class SpecTest < Minitest::Test
  include Badger::Geometry

  FIXTURES = File.expand_path("fixtures", __dir__)

  def setup
    Badger::Fonts.reset!.add_directory(FIXTURES)
  end

  def teardown = Badger::Fonts.reset!

  def stockholm
    YAML.safe_load(<<~YAML)
      name: Stockholm
      shape: { kind: ellipse, rx: 260, ry: 170 }
      regions:
        - { kind: rule, name: outer, distance: 0, weight: 5 }
        - { kind: band, name: ring, outer: -8, width: 40 }
        - { kind: rule, name: inner, distance: -50, weight: 2 }
        - { kind: interior, name: field, inside: -52 }
      type:
        - { mode: follow, text: HOH HIH, font: badger-test, region: ring, inset: 7, sweep: top, align: justify }
        - { mode: follow, text: "AV", font: badger-test, region: ring, from: outer, inset: 7, sweep: bottom, tracking: 10, size: 20 }
        - { mode: fit, text: H, font: badger-test, region: field, fit: chord_at_x, at: 0, inset: 30, name: mark }
        - { mode: fixed, text: HI, font: badger-test, size: 12, at: { polar: { angle: 90, radius: 100 } }, align: top }
      children:
        - name: medallion
          shape: { kind: circle, radius: 40 }
          visible: false
          at: { axial: [0.5, 0.5] }
          regions:
            - { kind: rule, distance: 0, weight: 2 }
    YAML
  end

  def test_builds_the_whole_tree
    container = Badger::Spec.build(stockholm)
    assert_equal "Stockholm", container.name
    assert_equal 4, container.regions.size
    assert_equal ["HOH HIH", "AV", "mark", "HI", "medallion"], container.nodes.map(&:name)
    output = Badger.render(container)
    assert_equal %w[ground ink], output.slots.map(&:name)
    assert_includes output.pieces.map(&:kind), :type
    medallion = output.pieces.find { |p| p.depth == 1 && p.kind == :region }
    assert medallion
  end

  def test_follow_fits_the_band_by_default_and_sweeps_the_top
    container = Badger::Spec.build(stockholm)
    follow = container.nodes.first.child
    assert_kind_of Badger::Follow, follow
    assert_in_delta 40 - 14, follow.run.cap_height, 1e-6
    assert follow.placements.all? { |p| p.point.y < 0 }, "over the top"
    bottom = container.nodes[1].child
    assert_equal 20.0, bottom.run.size
    assert bottom.placements.all? { |p| p.point.y > 0 }, "along the bottom"
    assert_in_delta 10, bottom.tracking
  end

  def test_fit_and_fixed_items
    container = Badger::Spec.build(stockholm)
    mark = container.nodes[2]
    assert_kind_of Badger::Setting, mark.child
    field_height = 2 * (170 - 52) - 60
    assert_in_delta field_height, mark.bounds.then { |a, b| b.y - a.y }, 1.5
    fixed = container.nodes[3]
    assert_in_delta 100, fixed.bounds[0].y, 1e-6, "top edge on the polar locator"
  end

  def test_string_and_symbol_keys_both_work
    symbolic = { name: "S", shape: { kind: :circle, radius: 50 }, regions: [{ kind: :rule, distance: 0 }] }
    assert_equal 1, Badger::Spec.build(symbolic).regions.size
  end

  def test_box_fit_with_stretch_and_illustration_inline
    doc = {
      "shape" => { "kind" => "rectangle", "width" => 300, "height" => 200 },
      "type" => [{ "mode" => "fit", "fit" => "box", "text" => "HH", "font" => "badger-test", "width" => 200, "height" => 50,
                   "axes" => "both", "stretch" => { "min" => 0.25, "max" => 2 }, "at" => { "axial" => [0.5, 0.5] } }],
      "illustrations" => [{ "svg" => File.read(File.join(FIXTURES, "mono.svg")), "at" => { "axial" => [0, 0] },
                            "align" => "top_left", "fit" => { "width" => 40, "height" => 40 } }]
    }
    container = Badger::Spec.build(doc)
    text, art = container.nodes
    assert_in_delta 200, text.bounds.then { |a, b| b.x - a.x }, 1e-6
    assert_in_delta 50, text.bounds.then { |a, b| b.y - a.y }, 1e-6
    assert_equal :illustration, art.kind
    assert_point pt(-150, -100), art.bounds[0], 1e-6
    assert_in_delta 40, art.bounds.then { |a, b| b.x - a.x }, 1e-6
  end

  def test_file_illustrations_resolve_against_base_dir
    doc = { "shape" => { "kind" => "circle", "radius" => 100 }, "illustrations" => [{ "file" => "mono.svg" }] }
    assert_equal 1, Badger::Spec.new(doc, base_dir: FIXTURES).container.nodes.size
    assert_raises(Badger::Spec::Error) { Badger::Spec.build(doc) }
  end

  def test_sweep_fractions_and_rotation_on_path
    doc = {
      "shape" => { "kind" => "circle", "radius" => 100 },
      "regions" => [{ "kind" => "band", "name" => "ring", "outer" => 0, "width" => 30 }],
      "type" => [{ "mode" => "follow", "text" => "HH", "font" => "badger-test", "region" => "ring",
                   "sweep" => { "start" => 0.25, "length" => 0.5 }, "size" => 10, "align" => "start" },
                 { "mode" => "fixed", "text" => "I", "font" => "badger-test", "size" => 10,
                   "at" => { "on_path" => 0.5 }, "align" => "bottom", "rotate" => "tangent" }]
    }
    container = Badger::Spec.build(doc)
    follow = container.nodes.first.child
    assert_in_delta 0.25 * follow.spine.length, follow.start
    assert_in_delta 0.5 * follow.spine.length, follow.sweep
    turned = container.nodes.last
    assert_in_delta 7, turned.bounds.then { |a, b| b.x - a.x }, 1e-6, "rotated a quarter turn at the left of the circle"
  end

  def test_errors_say_where_and_what
    e = assert_raises(Badger::Spec::Error) { Badger::Spec.build({ "shape" => { "kind" => "hexagon" } }) }
    assert_match(/badge\.shape: kind must be one of/, e.message)
    e = assert_raises(Badger::Spec::Error) { Badger::Spec.build({ "shape" => { "kind" => "circle" } }) }
    assert_match(/badge\.shape: needs radius/, e.message)
    doc = { "shape" => { "kind" => "circle", "radius" => 10 }, "type" => [{ "mode" => "follow", "text" => "H", "font" => "badger-test", "region" => "nope" }] }
    e = assert_raises(Badger::Spec::Error) { Badger::Spec.build(doc) }
    assert_match(/badge\.type\[0\]: names region "nope"/, e.message)
    doc["type"] = [{ "mode" => "fixed", "text" => "H", "font" => "Missing", "size" => 10 }]
    e = assert_raises(Badger::Spec::Error) { Badger::Spec.build(doc) }
    assert_match(/no font named "Missing"/, e.message)
    doc["type"] = [{ "mode" => "fixed", "text" => "H", "font" => "badger-test", "size" => 10, "at" => { "orbit" => 1 } }]
    e = assert_raises(Badger::Spec::Error) { Badger::Spec.build(doc) }
    assert_match(/at must be centroid/, e.message)
    e = assert_raises(Badger::Spec::Error) { Badger::Spec.build({ "shape" => { "kind" => "circle", "radius" => 10 }, "slot" => "paper" }) }
    assert_match(/unknown slot/, e.message)
  end
end
