# frozen_string_literal: true

require "test_helper"

class LocatorTest < Minitest::Test
  include Badger::Geometry

  def rect = (@rect ||= Badger::Container.new(Path.rect(0, 0, 100, 50)))

  def test_centroid_and_bounds_of_a_container
    assert_point pt(50, 25), rect.centroid
    assert_equal [pt(0, 0), pt(100, 50)], rect.bounds
    circle = Badger::Container.new(Ellipse.circle(40, center: pt(10, 20)))
    assert_point pt(10, 20), circle.centroid, 1e-6
  end

  def test_centroid_locator
    anchor = Badger::Locator.centroid.resolve(rect)
    assert_point pt(50, 25), anchor.point
    assert_nil anchor.angle
  end

  def test_polar_locator_is_visual_degrees_from_the_centroid
    up = Badger::Locator.polar(angle: -90, radius: 20).resolve(rect)
    assert_point pt(50, 5), up.point
    assert_in_delta(-90, up.degrees)
    right = Badger::Locator.polar(angle: 0, radius: 30).resolve(rect)
    assert_point pt(80, 25), right.point
  end

  def test_axial_locator_is_fractions_of_the_bounds
    assert_point pt(0, 0), Badger::Locator.axial(0, 0).resolve(rect).point
    assert_point pt(100, 50), Badger::Locator.axial(1, 1).resolve(rect).point
    assert_point pt(25, 40), Badger::Locator.axial(0.25, 0.8).resolve(rect).point
  end

  def test_on_path_locator_by_fraction_or_length_with_the_tangent
    quarter = Badger::Locator.on_path(fraction: 0.25).resolve(rect)
    assert_point pt(75, 0), quarter.point
    assert_in_delta 0, quarter.degrees
    side = Badger::Locator.on_path(length: 125).resolve(rect)
    assert_point pt(100, 25), side.point
    assert_in_delta 90, side.degrees
    assert_raises(ArgumentError) { Badger::Locator.on_path }
    assert_raises(ArgumentError) { Badger::Locator.on_path(fraction: 0.1, length: 5) }
  end
end

class AlignmentTest < Minitest::Test
  include Badger::Geometry

  BOUNDS = [Point.new(10.0, 20.0), Point.new(50.0, 60.0)].freeze

  def test_nine_named_points
    assert_point pt(10, 20), Badger::Alignment.reference(BOUNDS, :top_left)
    assert_point pt(30, 20), Badger::Alignment.reference(BOUNDS, :top)
    assert_point pt(50, 20), Badger::Alignment.reference(BOUNDS, :top_right)
    assert_point pt(10, 40), Badger::Alignment.reference(BOUNDS, :left)
    assert_point pt(30, 40), Badger::Alignment.reference(BOUNDS, :center)
    assert_point pt(50, 40), Badger::Alignment.reference(BOUNDS, :right)
    assert_point pt(10, 60), Badger::Alignment.reference(BOUNDS, :bottom_left)
    assert_point pt(30, 60), Badger::Alignment.reference(BOUNDS, :bottom)
    assert_point pt(50, 60), Badger::Alignment.reference(BOUNDS, :bottom_right)
  end

  def test_custom_pair_and_errors
    assert_point pt(14, 56), Badger::Alignment.reference(BOUNDS, [0.1, 0.9])
    assert_raises(ArgumentError) { Badger::Alignment.reference(BOUNDS, :middle) }
    assert_raises(ArgumentError) { Badger::Alignment.reference(BOUNDS, [1]) }
    assert_raises(ArgumentError) { Badger::Alignment.reference(BOUNDS, "center") }
  end
end

class TreeTest < Minitest::Test
  include Badger::Geometry

  FONT = File.expand_path("fixtures/badger-test.ttf", __dir__)

  def font = (@font ||= Badger::Font.new(FONT))
  def parent = (@parent ||= Badger::Container.new(Path.rect(0, 0, 400, 200), name: "parent"))

  def test_place_type_by_polar_locator_and_edge_alignment
    setting = Badger::Setting.new(font.shape("HH", size: 50)) # ink 60 wide, 35 tall, above the baseline
    node = parent.place(setting, at: Badger::Locator.polar(angle: 0, radius: 150), align: :right, name: "right label")
    min, max = node.bounds
    assert_point pt(350, 100), pt(max.x, (min.y + max.y) / 2), 1e-6
    assert_in_delta 60, max.x - min.x, 1e-6
    assert_equal :type, node.kind
    assert_equal [node], parent.nodes
    assert_equal [setting], parent.children
  end

  def test_symmetric_pair_anchored_to_different_edges_holds_its_edges
    left = parent.place(Badger::Setting.new(font.shape("I", size: 50)), at: Badger::Locator.polar(angle: 180, radius: 150), align: :left)
    right = parent.place(Badger::Setting.new(font.shape("HHHH", size: 50)), at: Badger::Locator.polar(angle: 0, radius: 150), align: :right)
    assert_in_delta 50, left.bounds[0].x, 1e-6
    assert_in_delta 350, right.bounds[1].x, 1e-6
    longer = parent.place(Badger::Setting.new(font.shape("HHHHHH", size: 50)), at: Badger::Locator.polar(angle: 0, radius: 150), align: :right)
    assert_in_delta 350, longer.bounds[1].x, 1e-6, "the anchored edge stays put as the string grows"
  end

  def test_place_a_child_container_and_resolve_outside_in
    child = Badger::Container.new(Ellipse.circle(40), name: "medallion", visible: false)
    child.rule(0, weight: 4, name: "medallion rule")
    node = parent.place(child, at: Badger::Locator.axial(0.5, 0.5), align: :center)
    assert_equal :container, node.kind
    assert_point pt(160, 60), node.bounds[0], 0.2
    assert_point pt(240, 140), node.bounds[1], 0.2

    resolved = parent.resolve
    assert_equal %i[container region], resolved.map(&:kind)
    assert_equal ["parent", "medallion rule"], resolved.map(&:name)
    assert_equal [0, 1], resolved.map(&:depth)
    rule = resolved.last
    assert_point pt(158, 58), rule.path.bounds[0], 0.2
    assert_point pt(242, 142), rule.path.bounds[1], 0.2
  end

  def test_nested_children_compose_affines
    child = Badger::Container.new(Path.rect(0, 0, 100, 100), name: "child")
    grandchild = Badger::Setting.new(font.shape("H", size: 100)) # ink 60 x 70
    child.place(grandchild, at: Badger::Locator.axial(0, 0), align: :top_left, name: "grandchild")
    parent.place(child, at: Badger::Locator.axial(1, 1), align: :bottom_right)
    resolved = parent.resolve
    text = resolved.find { |r| r.kind == :type }
    assert_equal "grandchild", text.name
    assert_equal 2, text.depth
    assert_point pt(300, 100), text.path.bounds[0], 1e-6
    assert_point pt(360, 170), text.path.bounds[1], 1e-6
  end

  def test_rotation_to_a_tangent_and_by_degrees
    setting = Badger::Setting.new(font.shape("HH", size: 50))
    side = parent.place(setting, at: Badger::Locator.on_path(length: 500), align: :bottom, rotate: :tangent)
    min, max = side.bounds
    assert_in_delta 35, max.x - min.x, 1e-6, "rotated a quarter turn: width and height swap"
    assert_in_delta 60, max.y - min.y, 1e-6
    assert_in_delta 400, min.x, 1e-6, "the bottom of the type sits on the right edge, facing out"

    turned = parent.place(setting, at: Badger::Locator.centroid, align: :center, rotate: 180)
    min, max = turned.bounds
    assert_point pt(200, 100), (min + max) / 2, 1e-6

    assert_raises(ArgumentError) { parent.place(setting, at: Badger::Locator.centroid, rotate: :tangent) }
    assert_raises(ArgumentError) { parent.place(setting, at: Badger::Locator.centroid, rotate: :sideways) }
  end

  def test_attach_keeps_the_child_in_place
    band = parent.band(outer: -5, width: 30)
    follow = Badger::Follow.new(band.baseline(5), font.shape("HHH", size: 20), start: 0, sweep: 300)
    node = parent.attach(follow, name: "ring")
    assert_equal follow.path.to_d, node.path.to_d
    assert_equal :type, node.kind
  end

  def test_world_transform_moves_and_scales_the_whole_badge
    parent.rule(0, weight: 2)
    parent.place(Badger::Setting.new(font.shape("H", size: 50)), at: Badger::Locator.centroid)
    moved = parent.resolve(world: Affine.translate(1000, 0) * Affine.scale(0.5))
    silhouette = moved.first
    assert_point pt(1000, 0), silhouette.path.bounds[0], 1e-6
    assert_point pt(1200, 100), silhouette.path.bounds[1], 1e-6
    rule = moved[1]
    assert_in_delta 999.5, rule.path.bounds[0].x, 1e-6, "a 2-wide rule at half scale reaches 0.5 past the edge"
    glyph = moved.last
    assert_point pt(1100, 50), (glyph.path.bounds[0] + glyph.path.bounds[1]) / 2, 1e-6
  end

  def test_invisible_containers_still_anchor
    line = Badger::Container.new(Path.rect(0, 0, 200, 1), visible: false)
    node = line.place(Badger::Setting.new(font.shape("H", size: 10)), at: Badger::Locator.axial(0.5, 0), align: :bottom)
    assert_empty line.resolve.select { |r| r.kind == :container }
    assert_equal 1, line.resolve.size
    assert_in_delta 0, node.bounds[1].y, 1e-6
  end

  def test_a_bare_path_places_as_illustration
    star = Path.rect(-5, -5, 10, 10)
    node = parent.place(star, at: Badger::Locator.on_path(fraction: 0.25), align: :bottom, rotate: :tangent, name: "star")
    assert_equal :illustration, node.kind
    assert_point pt(300, 0), Badger::Alignment.reference(node.bounds, :bottom), 1e-6
    resolved = parent.resolve.last
    assert_equal :illustration, resolved.kind
    assert_equal "star", resolved.name
  end

  def test_placing_something_without_bounds_fails_clearly
    assert_raises(ArgumentError) { parent.place("text", at: Badger::Locator.centroid) }
  end
end
