# frozen_string_literal: true

require "test_helper"

class OffsetTest < Minitest::Test
  include Badger::Geometry

  def test_outward_offset_of_a_circle_is_a_larger_circle
    spine = Ellipse.circle(100).spine
    outer = spine.offset(20, tolerance: 0.05)
    assert outer.closed?
    assert_in_delta 2 * Math::PI * 120, outer.length, 2 * Math::PI * 120 * 1e-3
    outer.flatten.each { |p| assert_in_delta 120, p.length, 0.06 }
  end

  def test_inward_offset_of_a_circle_is_a_smaller_circle
    inner = Ellipse.circle(100).spine.offset(-30, tolerance: 0.05)
    assert_in_delta 2 * Math::PI * 70, inner.length, 2 * Math::PI * 70 * 1e-3
    inner.flatten.each { |p| assert_in_delta 70, p.length, 0.06 }
  end

  def test_offset_is_outward_regardless_of_winding
    clockwise = Path.rect(0, 0, 100, 50).spine
    counter = Path.polyline([pt(0, 0), pt(0, 50), pt(100, 50), pt(100, 0)], closed: true).spine
    [clockwise, counter].each do |spine|
      min, max = spine.offset(10).to_path.bounds
      assert_point pt(-10, -10), min
      assert_point pt(110, 60), max
      min, max = spine.offset(-10).to_path.bounds
      assert_point pt(10, 10), min
      assert_point pt(90, 40), max
    end
  end

  def test_convex_corners_get_round_joins_and_concave_ones_are_mitred
    rect = Path.rect(0, 0, 100, 50).spine
    outer = rect.offset(10, tolerance: 0.01)
    assert_in_delta 300 + 2 * Math::PI * 10, outer.length, 0.05
    inner = rect.offset(-10)
    assert_in_delta 300 - 80, inner.length, 1e-9
    assert_equal 4, inner.flatten.size
  end

  def test_offset_of_an_ellipse_keeps_a_constant_distance
    ellipse = Ellipse.new(rx: 200, ry: 80)
    dense = ellipse.flatten(0.01)
    ellipse.spine.offset(15, tolerance: 0.02).flatten.each_slice(7) do |slice|
      p = slice.first
      nearest = dense.map { |q| q.distance_to(p) }.min
      assert_in_delta 15, nearest, 0.05
    end
  end

  def test_open_spine_offsets_toward_the_up_normal
    line = Path.polyline([pt(0, 0), pt(100, 0)]).spine
    up = line.offset(5).flatten
    assert_equal [pt(0, -5), pt(100, -5)], up
    down = line.offset(-5).flatten
    assert_equal [pt(0, 5), pt(100, 5)], down
  end

  def test_open_polyline_with_a_convex_corner
    spine = Path.polyline([pt(0, 0), pt(100, 0), pt(100, 100)]).spine
    offset = spine.offset(10, tolerance: 0.01)
    assert_in_delta 200 + Math::PI / 2 * 10, offset.length, 0.02
    assert_point pt(0, -10), offset.start_point
    assert_point pt(110, 100), offset.end_point
  end

  def test_zero_offset_returns_the_flattened_spine
    spine = Path.rect(0, 0, 10, 10).spine
    assert_equal spine.flatten, Offset.points(spine, 0)
  end

  def test_offset_spine_supports_arc_length_lookups
    ring = Ellipse.new(rx: 150, ry: 60).spine.offset(12)
    quarter = ring.point_at(ring.length / 4)
    assert_in_delta ring.length / 4, ring.at(ring.length / 4).length, 1e-9
    assert quarter.y.positive?
    assert_empty ring.corners
  end
end
