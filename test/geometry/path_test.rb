# frozen_string_literal: true

require "test_helper"

class PathTest < Minitest::Test
  include Badger::Geometry

  def test_parses_absolute_and_relative_lines
    path = Path.parse("M 10 10 L 20 10 l 0 10 H 10 v -5 Z")
    subpath = path.subpaths.first
    assert subpath.closed?
    assert_equal 5, subpath.segments.size
    assert_point pt(20, 20), subpath.segments[1].p1
    assert_point pt(10, 20), subpath.segments[2].p1
    assert_point pt(10, 15), subpath.segments[3].p1
    assert_point pt(10, 10), subpath.segments[4].p1
  end

  def test_implicit_lineto_after_moveto_and_repeated_coordinates
    path = Path.parse("M0,0 10,0 10,10")
    assert_equal 2, path.subpaths.first.segments.size
    assert path.subpaths.first.segments.all?(Line)
    path = Path.parse("m 5 5 10 0 0 10")
    assert_point pt(15, 15), path.subpaths.first.segments.last.p1
  end

  def test_compact_number_syntax
    path = Path.parse("M1.5.5L-2-3e1")
    assert_point pt(1.5, 0.5), path.subpaths.first.start_point
    assert_point pt(-2, -30), path.subpaths.first.segments.first.p1
  end

  def test_cubics_smooth_cubics_and_quadratics
    path = Path.parse("M 0 0 C 0 50 100 50 100 0 S 200 -50 200 0 Q 250 50 300 0 T 400 0")
    segments = path.subpaths.first.segments
    assert_equal 4, segments.size
    assert segments.all?(Cubic)
    assert_point pt(100, -50), segments[1].p1 # reflected control point
    assert_point pt(350, -50), segments[3].p1 + (segments[3].p1 - segments[3].p0) / 2 # reflected quadratic control
  end

  def test_arc_commands_become_cubics_with_the_right_length
    circle = Path.parse("M 0 -50 A 50 50 0 1 1 0 50 A 50 50 0 1 1 0 -50 Z")
    assert_in_delta 2 * Math::PI * 50, circle.spine.length, 2 * Math::PI * 50 * 3e-4
    assert circle.subpaths.first.closed?
  end

  def test_arc_flags_without_separators
    a = Path.parse("M 0 0 A 10 10 0 0 1 20 0")
    b = Path.parse("M 0 0 A 10 10 0 0120 0")
    c = Path.parse("M 0 0 a10,10 0 0,1 20,0")
    assert_in_delta a.spine.length, b.spine.length, 1e-9
    assert_in_delta a.spine.length, c.spine.length, 1e-9
    assert_in_delta Math::PI * 10, a.spine.length, Math::PI * 10 * 3e-4
  end

  def test_arc_sweep_flag_picks_the_side
    upper = Path.parse("M -10 0 A 10 10 0 0 1 10 0").spine
    lower = Path.parse("M -10 0 A 10 10 0 0 0 10 0").spine
    assert_in_delta(-10, upper.point_at(upper.length / 2).y, 1e-2)
    assert_in_delta 10, lower.point_at(lower.length / 2).y, 1e-2
  end

  def test_rotated_elliptical_arc
    path = Path.parse("M 0 0 A 100 50 30 1 0 10 10")
    spine = path.spine
    assert_point pt(10, 10), spine.end_point
    assert_operator spine.length, :>, 200
  end

  def test_degenerate_arc_is_a_line
    path = Path.parse("M 0 0 A 0 10 0 0 1 20 0")
    assert_kind_of Line, path.subpaths.first.segments.first
  end

  def test_multiple_subpaths
    path = Path.parse("M 0 0 L 10 0 M 20 0 L 30 0 Z M 40 0 L 50 0")
    assert_equal 3, path.subpaths.size
    assert_equal [false, true, false], path.subpaths.map(&:closed?)
  end

  def test_to_d_round_trips
    d = "M 0 0 L 10 0 C 10 5 5 10 0 10 Z M 20 20 L 30 30"
    path = Path.parse(d)
    assert_equal d, path.to_d
    assert_equal d, Path.parse(path.to_d).to_d
  end

  def test_rect_and_polyline
    rect = Path.rect(0, 0, 100, 50)
    assert_equal 300.0, rect.spine.length
    assert_equal [pt(0, 0), pt(100, 50)], rect.bounds
    open = Path.polyline([pt(0, 0), pt(3, 4)])
    assert_in_delta 5.0, open.spine.length
    refute open.spine.closed?
  end

  def test_circle_helper
    assert_in_delta 2 * Math::PI * 40, Path.circle(pt(0, 0), 40).spine.length, 0.05
  end

  def test_parse_errors
    assert_raises(SvgPathParser::ParseError) { Path.parse("10 10 L 20 20") }
    assert_raises(SvgPathParser::ParseError) { Path.parse("M 10") }
    assert_raises(SvgPathParser::ParseError) { Path.parse("M 0 0 A 10 10 0 2 1 20 0") }
  end
end
