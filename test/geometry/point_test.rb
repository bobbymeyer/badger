# frozen_string_literal: true

require "test_helper"

class PointTest < Minitest::Test
  def test_arithmetic
    a = pt(1, 2)
    b = pt(3, 5)
    assert_point pt(4, 7), a + b
    assert_point pt(-2, -3), a - b
    assert_point pt(2, 4), a * 2
    assert_point pt(0.5, 1), a / 2
    assert_point pt(-1, -2), -a
  end

  def test_products_and_lengths
    assert_equal 13.0, pt(1, 2).dot(pt(3, 5))
    assert_equal(-1.0, pt(1, 2).cross(pt(3, 5)))
    assert_equal 5.0, pt(3, 4).length
    assert_equal 5.0, pt(0, 0).distance_to(pt(3, 4))
    assert_point pt(0.6, 0.8), pt(3, 4).normalized
  end

  def test_normalizing_zero_raises
    assert_raises(Badger::Error) { pt(0, 0).normalized }
  end

  def test_perp_points_up_for_a_rightward_tangent
    assert_point pt(0, -1), pt(1, 0).perp
  end

  def test_rotate_is_clockwise_on_screen
    assert_point pt(0, 1), pt(1, 0).rotate(Math::PI / 2)
  end

  def test_lerp_angle_and_approx
    assert_point pt(2.5, 5), pt(0, 0).lerp(pt(5, 10), 0.5)
    assert_in_delta Math::PI / 2, pt(0, 3).angle
    assert pt(1, 1).approx?(pt(1 + 1e-12, 1))
    refute pt(1, 1).approx?(pt(1.1, 1))
  end
end
