# frozen_string_literal: true

require "test_helper"

class ContainerTest < Minitest::Test
  include Badger::Geometry

  def circle(r = 100) = Badger::Container.new(Ellipse.circle(r, center: pt(200, 200)))

  def test_builds_from_ellipse_path_or_spine
    assert_in_delta 2 * Math::PI * 100, circle.length, 1e-9
    assert_equal 300.0, Badger::Container.new(Path.rect(0, 0, 100, 50)).length
    assert_equal 300.0, Badger::Container.new(Path.rect(0, 0, 100, 50).spine).length
  end

  def test_rejects_open_paths_and_unknown_sources
    assert_raises(ArgumentError) { Badger::Container.new(Path.polyline([pt(0, 0), pt(1, 1)])) }
    assert_raises(ArgumentError) { Badger::Container.new("M 0 0") }
  end

  def test_visibility_and_naming
    c = Badger::Container.new(Ellipse.circle(10), visible: false, name: "setting line")
    refute c.visible?
    assert_equal "setting line", c.name
    assert Badger::Container.new(Ellipse.circle(10)).visible?
  end

  def test_offsets_are_memoized_and_shared_between_regions
    c = circle
    band = c.band(outer: -10, inner: -50)
    rule = c.rule(-50)
    assert_same band.inner_edge, rule.spine
    assert_same c.offset(0), c.spine
  end

  def test_regions_are_collected_in_order_and_filtered_by_visibility
    c = circle
    outer = c.rule(0, weight: 3)
    band = c.band(outer: -3, width: 40)
    inner = c.rule(-43, weight: 2, visible: true)
    interior = c.interior(inside: -44)
    assert_equal [outer, band, inner, interior], c.regions
    assert_equal [outer, inner], c.visible_regions
  end
end

class OffsetRegionTest < Minitest::Test
  include Badger::Geometry

  def container = (@container ||= Badger::Container.new(Ellipse.circle(100, center: pt(200, 200))))

  def test_rule_geometry
    rule = container.rule(10, weight: 4)
    assert_in_delta 2 * Math::PI * 110, rule.spine.length, 2 * Math::PI * 110 * 1e-3
    assert_in_delta 2 * Math::PI * 112, rule.outer_edge.length, 2 * Math::PI * 112 * 1e-3
    assert_in_delta 2 * Math::PI * 108, rule.inner_edge.length, 2 * Math::PI * 108 * 1e-3
    assert_equal 2, rule.path.subpaths.size
    min, max = rule.bounds
    assert_point pt(88, 88), min, 0.1
    assert_point pt(312, 312), max, 0.1
  end

  def test_rule_ring_has_opposite_windings
    rule = container.rule(0, weight: 6)
    outer, inner = rule.path.subpaths.map { |s| Offset.signed_area(s.spine.flatten(0.1)) }
    assert_operator outer * inner, :<, 0
  end

  def test_rule_is_visible_by_default_and_needs_positive_weight
    assert container.rule(0).visible?
    refute container.rule(0, visible: false).visible?
    assert_raises(ArgumentError) { container.rule(0, weight: 0) }
  end
end

class BandRegionTest < Minitest::Test
  include Badger::Geometry

  def container = (@container ||= Badger::Container.new(Ellipse.circle(100, center: pt(200, 200))))

  def test_edges_width_and_spines
    band = container.band(outer: -10, inner: -50)
    assert_equal 40.0, band.width
    assert_in_delta 2 * Math::PI * 90, band.outer_edge.length, 2 * Math::PI * 90 * 1e-3
    # a flattened circle offset inward keeps its chord count, so the shortfall grows with the offset
    assert_in_delta 2 * Math::PI * 50, band.inner_edge.length, 2 * Math::PI * 50 * 2e-3
    assert_same band.inner_edge, band.spine_at(0)
    assert_same band.outer_edge, band.spine_at(1)
    assert_in_delta 2 * Math::PI * 70, band.middle.length, 2 * Math::PI * 70 * 1e-3
  end

  def test_width_form
    band = container.band(outer: 0, width: 30)
    assert_equal(-30.0, band.inner)
    assert_equal 30.0, band.width
  end

  def test_baseline_inset_from_either_edge
    band = container.band(outer: -10, inner: -50)
    assert_same container.offset(-44), band.baseline(6)
    assert_same container.offset(-16), band.baseline(6, from: :outer)
    assert_raises(ArgumentError) { band.baseline(50) }
    assert_raises(ArgumentError) { band.baseline(5, from: :middle) }
    assert_raises(ArgumentError) { band.spine_at(1.5) }
  end

  def test_fill_path_is_an_annulus_and_invisible_by_default
    band = container.band(outer: -10, inner: -50)
    refute band.visible?
    assert_equal 2, band.path.subpaths.size
    min, max = band.bounds
    assert_point pt(110, 110), min, 0.1
    assert_point pt(290, 290), max, 0.1
  end

  def test_argument_validation
    assert_raises(ArgumentError) { container.band(outer: -50, inner: -10) }
    assert_raises(ArgumentError) { container.band(outer: 0) }
    assert_raises(ArgumentError) { container.band(outer: 0, inner: -5, width: 5) }
  end

  def test_following_type_on_a_band_baseline
    band = container.band(outer: 0, width: 40)
    baseline = band.baseline(8)
    follow = Badger::Follow.new(baseline, [20] * 6, start: baseline.length / 2, sweep: baseline.length / 2, align: :justify)
    assert follow.fits?
    assert follow.placements.all? { |p| p.point.y < 200 }
  end
end

class InteriorRegionTest < Minitest::Test
  include Badger::Geometry

  def test_circle_interior
    interior = Badger::Container.new(Ellipse.circle(100, center: pt(200, 200))).interior(inside: -20)
    assert_point pt(200, 200), interior.centroid, 1e-6
    a, b = interior.chord_at_y(200)
    assert_in_delta 120, a, 0.1
    assert_in_delta 280, b, 0.1
    assert_in_delta 160, interior.width_at_y(200), 0.2
    assert_in_delta 160, interior.height_at_x(200), 0.2
    assert_nil interior.chord_at_y(50)
    assert_nil interior.width_at_y(500)
    chord = interior.chord_at_y(200 + 48) # 80 * cos(asin(0.6)) = 64
    assert_in_delta 200 - 64, chord[0], 0.2
    assert_in_delta 200 + 64, chord[1], 0.2
  end

  def test_rectangle_interior_with_inset
    interior = Badger::Container.new(Path.rect(0, 0, 200, 100)).interior(inside: -10)
    min, max = interior.bounds
    assert_point pt(10, 10), min
    assert_point pt(190, 90), max
    assert_point pt(100, 50), interior.centroid
    assert_equal [10.0, 190.0], interior.chord_at_y(50)
    assert_equal [10.0, 90.0], interior.chord_at_x(20)
    assert_equal 1, interior.path.subpaths.size
  end

  def test_non_convex_interior_returns_every_span_and_picks_the_right_one
    # a C shape: 100 wide, 100 tall, with a 60x40 notch cut from the right side
    c_shape = Path.polyline([pt(0, 0), pt(100, 0), pt(100, 30), pt(40, 30), pt(40, 70), pt(100, 70), pt(100, 100), pt(0, 100)],
                            closed: true)
    interior = Badger::Container.new(c_shape).interior
    assert_equal [[0.0, 40.0]], interior.spans_at_y(50)
    assert_equal [[0.0, 100.0]], interior.spans_at_y(15)
    assert_equal [[0.0, 30.0], [70.0, 100.0]], interior.spans_at_x(60)
    assert_equal [70.0, 100.0], interior.chord_at_x(60, through: 80)
    assert_equal [0.0, 30.0], interior.chord_at_x(60, through: 10)
    assert_equal [0.0, 30.0], interior.chord_at_x(60, through: 50), "outside every span: the widest wins"
  end

  def test_validation_and_default
    container = Badger::Container.new(Path.rect(0, 0, 10, 10))
    assert_raises(ArgumentError) { container.interior(inside: 5) }
    assert_same container.spine, container.interior.spine
    refute container.interior.visible?
  end
end
