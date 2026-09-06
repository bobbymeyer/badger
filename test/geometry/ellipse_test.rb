# frozen_string_literal: true

require "test_helper"

class EllipseTest < Minitest::Test
  include Badger::Geometry

  def test_circle_perimeter
    assert_in_delta 2 * Math::PI * 100, Ellipse.circle(100).length, 1e-9
  end

  def test_ellipse_perimeter_against_known_value
    # Perimeter of the 2:1 ellipse, from the complete elliptic integral.
    assert_in_delta 9.688448220547675, Ellipse.new(rx: 2, ry: 1).length, 1e-9
  end

  def test_highly_eccentric_ellipse_perimeter_against_series
    rx = 300.0
    ry = 40.0
    # Gauss-Kummer series, summed far enough to converge.
    h = ((rx - ry) / (rx + ry))**2
    series = 1.0
    term = 1.0
    (1..60).each do |n|
      coefficient = (2.0 * n - 3) / (2.0 * n)
      coefficient = 0.5 if n == 1
      term *= coefficient**2 * h
      series += term
    end
    expected = Math::PI * (rx + ry) * series
    assert_in_delta expected, Ellipse.new(rx: rx, ry: ry).length, 1e-6
  end

  def test_parameterization_runs_clockwise_on_screen
    e = Ellipse.new(rx: 100, ry: 50, center: pt(10, 20))
    assert_point pt(110, 20), e.point(0)
    assert_point pt(10, 70), e.point(0.25)   # bottom, in y-down space
    assert_point pt(-90, 20), e.point(0.5)
    assert_point pt(10, -30), e.point(0.75)  # top
  end

  def test_rotation
    e = Ellipse.new(rx: 100, ry: 50, rotation: Math::PI / 2)
    assert_point pt(0, 100), e.point(0)
    assert_point pt(-50, 0), e.point(0.25)
  end

  def test_tangent_at_top_reads_left_to_right_with_up_pointing_out
    e = Ellipse.new(rx: 100, ry: 50)
    tangent = e.derivative(0.75).normalized
    assert_point pt(1, 0), tangent
    assert_point pt(0, -1), tangent.perp
  end

  def test_param_at_polar_hits_the_requested_visual_angle
    e = Ellipse.new(rx: 200, ry: 50)
    [0.3, 1.0, 2.0, 4.0, 5.5].each do |phi|
      p = e.point(e.param_at_polar(phi))
      assert_in_delta phi % TAU, p.angle % TAU, 1e-9
    end
    assert_in_delta 0.75, e.param_at_polar(-Math::PI / 2)
  end

  def test_param_at_polar_respects_rotation
    e = Ellipse.new(rx: 200, ry: 50, rotation: 0.4)
    p = e.point(e.param_at_polar(1.2))
    assert_in_delta 1.2, p.angle, 1e-9
  end

  def test_flatten_points_are_on_the_curve_and_within_tolerance
    e = Ellipse.new(rx: 200, ry: 50)
    points = e.flatten(0.1)
    assert_equal points.first, points.last
    points.each do |p|
      assert_in_delta 1.0, (p.x / 200)**2 + (p.y / 50)**2, 1e-9
    end
    points.each_cons(2) do |a, b|
      mid = a.lerp(b, 0.5)
      # radial distance of the chord midpoint from the ellipse, in the local scale
      assert_operator 1.0 - Math.sqrt((mid.x / 200)**2 + (mid.y / 50)**2), :<=, 0.1 / 50
    end
  end

  def test_to_cubics_approximates_the_ellipse
    e = Ellipse.new(rx: 150, ry: 60, center: pt(5, 5), rotation: 0.3)
    spine = e.to_path.spine
    assert_in_delta e.length, spine.length, e.length * 3e-4
    assert_point e.point(0), spine.start_point
    assert_point e.point(0.25), e.to_cubics[1].p0
  end

  def test_invalid_radii
    assert_raises(ArgumentError) { Ellipse.new(rx: 0, ry: 1) }
  end
end
