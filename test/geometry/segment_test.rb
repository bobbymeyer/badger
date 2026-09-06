# frozen_string_literal: true

require "test_helper"

class SegmentTest < Minitest::Test
  include Badger::Geometry

  def test_line_is_exact
    line = Line.new(pt(0, 0), pt(3, 4))
    assert_equal 5.0, line.length
    assert_point pt(1.5, 2), line.point(0.5)
    assert_point pt(3, 4), line.derivative(0.3)
    assert_equal [pt(0, 0), pt(3, 4)], line.flatten(0.1)
    assert_point pt(3, 4), line.reversed.p0
  end

  def test_cubic_endpoints_and_tangents
    c = Cubic.new(pt(0, 0), pt(0, 50), pt(100, 50), pt(100, 0))
    assert_point pt(0, 0), c.point(0)
    assert_point pt(100, 0), c.point(1)
    assert_point pt(50, 37.5), c.point(0.5)
    assert_point pt(0, 150), c.derivative(0)
    assert_point pt(0, -150), c.derivative(1)
  end

  def test_cubic_length_matches_a_fine_polyline
    c = Cubic.new(pt(0, 0), pt(0, 50), pt(100, 50), pt(100, 0))
    polyline = (0..20_000).map { |i| c.point(i / 20_000.0) }.each_cons(2).sum { |a, b| a.distance_to(b) }
    assert_in_delta polyline, c.length, 1e-6
  end

  def test_split_halves_agree_with_the_whole
    c = Cubic.new(pt(0, 0), pt(30, 80), pt(70, -40), pt(100, 20))
    a, b = c.split(0.5)
    assert_point c.point(0.25), a.point(0.5)
    assert_point c.point(0.75), b.point(0.5)
    assert_in_delta c.length, a.length + b.length, 1e-9
  end

  def test_flatten_stays_within_tolerance
    c = Cubic.new(pt(0, 0), pt(0, 100), pt(200, 100), pt(200, 0))
    tolerance = 0.5
    points = c.flatten(tolerance)
    assert_equal c.p0, points.first
    assert_equal c.p3, points.last
    assert points.size > 8
    # every chord midpoint must lie within tolerance of the curve
    dense = (0..20_000).map { |i| c.point(i / 20_000.0) }
    points.each_cons(2) do |a, b|
      mid = a.lerp(b, 0.5)
      assert_operator dense.map { |p| p.distance_to(mid) }.min, :<=, tolerance
    end
  end

  def test_quadratic_elevation_is_exact
    p0 = pt(0, 0)
    ctrl = pt(50, 100)
    p2 = pt(100, 0)
    c = Cubic.from_quadratic(p0, ctrl, p2)
    [0.0, 0.3, 0.5, 0.8, 1.0].each do |t|
      mt = 1 - t
      quad = p0 * (mt * mt) + ctrl * (2 * mt * t) + p2 * (t * t)
      assert_point quad, c.point(t), 1e-9
    end
  end

  def test_reversed_cubic_traces_the_same_curve_backwards
    c = Cubic.new(pt(0, 0), pt(30, 80), pt(70, -40), pt(100, 20))
    r = c.reversed
    assert_point c.point(0.3), r.point(0.7)
    assert_point(-c.derivative(0.3), r.derivative(0.7))
  end
end
