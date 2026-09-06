# frozen_string_literal: true

require "test_helper"

class SpineTest < Minitest::Test
  include Badger::Geometry

  def rect_spine = Path.rect(0, 0, 100, 50).spine

  def test_closed_spine_wraps_and_open_spine_clamps
    closed = rect_spine
    assert_point closed.point_at(10), closed.point_at(310)
    assert_point closed.point_at(290), closed.point_at(-10)
    open = Path.polyline([pt(0, 0), pt(10, 0)]).spine
    assert_point pt(10, 0), open.point_at(50)
    assert_point pt(0, 0), open.point_at(-3)
  end

  def test_tangent_and_normal_on_a_rectangle
    at = rect_spine.at(50)
    assert_point pt(50, 0), at.point
    assert_point pt(1, 0), at.tangent
    assert_point pt(0, -1), at.normal
    assert_in_delta 0.0, at.degrees
    side = rect_spine.at(125)
    assert_point pt(100, 25), side.point
    assert_in_delta 90.0, side.degrees
  end

  def test_corners_of_a_rectangle
    assert_equal [0.0, 100.0, 150.0, 250.0], rect_spine.corners
    assert rect_spine.corner_between?(90, 110)
    refute rect_spine.corner_between?(10, 90)
    assert rect_spine.corner_between?(290, 310), "wraps across the start corner"
    refute rect_spine.corner_between?(260, 295)
    assert rect_spine.corner_between?(0, 400), "an interval longer than the spine covers every corner"
  end

  def test_smooth_junctions_are_not_corners
    assert_empty Ellipse.circle(50).to_path.spine.corners
    assert_empty Ellipse.circle(50).spine.corners
  end

  def test_corner_threshold_is_configurable
    spine = Path.polyline([pt(0, 0), pt(100, 0), pt(200, 20)]).spine
    assert_empty spine.corners
    assert_equal [100.0], Path.polyline([pt(0, 0), pt(100, 0), pt(200, 20)]).spine(corner_threshold: 5).corners
  end

  def test_sample_spacing
    closed = Ellipse.circle(10).spine.sample(4)
    assert_equal 4, closed.size
    assert_point pt(10, 0), closed[0]
    assert_point pt(0, 10), closed[1]
    open = Path.polyline([pt(0, 0), pt(30, 0)]).spine.sample(4)
    assert_equal [0.0, 10.0, 20.0, 30.0], open.map(&:x)
  end

  def test_reversed_spine_reads_the_other_way
    spine = Ellipse.new(rx: 100, ry: 50).spine
    reversed = spine.reversed
    assert_in_delta spine.length, reversed.length, 1e-9
    assert_point spine.point_at(30), reversed.point_at(spine.length - 30)
    at_bottom = reversed.at(reversed.length * 0.75)
    assert_point pt(0, 50), at_bottom.point
    assert_point pt(1, 0), at_bottom.tangent
    assert_point pt(0, -1), at_bottom.normal, 1e-6
  end

  def test_multi_piece_spine_locates_across_pieces
    spine = Path.parse("M 0 0 L 100 0 C 150 0 200 50 200 100").spine
    assert_point pt(50, 0), spine.point_at(50)
    assert_point pt(100, 0), spine.point_at(100)
    assert_point pt(200, 100), spine.point_at(spine.length)
    assert_in_delta 100.0, spine.length_at(1, 0.0)
    index, t = spine.locate(spine.length)
    assert_equal 1, index
    assert_in_delta 1.0, t
  end

  def test_flatten_does_not_repeat_the_closing_vertex
    points = rect_spine.flatten(0.1)
    assert_equal 4, points.size
    assert_equal 4, Path.parse("M 0 0 L 10 0 L 10 10 L 0 10 Z").spine.flatten(0.1).size
  end

  def test_to_path_keeps_exact_segments_and_flattens_the_rest
    assert_equal "M 0 0 L 100 0 L 100 50 L 0 50 Z", rect_spine.to_path.to_d
    ellipse = Ellipse.circle(10).spine.to_path
    assert_equal 4, ellipse.subpaths.first.segments.size
    reversed = Ellipse.circle(10).spine.reversed.to_path
    assert reversed.subpaths.first.segments.all?(Line)
  end

  def test_empty_spine_raises
    assert_raises(ArgumentError) { Spine.new([]) }
  end
end
