# frozen_string_literal: true

require "test_helper"

class ArcLengthTest < Minitest::Test
  include Badger::Geometry

  def test_circle_quarter_lengths_land_on_the_axes
    circle = Ellipse.circle(100)
    spine = circle.spine
    quarter = spine.length / 4
    assert_point pt(0, 100), spine.point_at(quarter)
    assert_point pt(-100, 0), spine.point_at(2 * quarter)
    assert_point pt(0, -100), spine.point_at(3 * quarter)
  end

  def test_forward_and_inverse_lookup_round_trip_on_a_cubic
    c = Cubic.new(pt(0, 0), pt(0, 200), pt(300, -100), pt(300, 100))
    table = c.arc_length_table
    [0.0, 0.05, 0.1, 0.33, 0.5, 0.61, 0.9, 0.999, 1.0].each do |t|
      s = table.length_at(t)
      assert_in_delta t, table.param_at(s), 1e-9
    end
  end

  def test_forward_and_inverse_lookup_round_trip_on_an_eccentric_ellipse
    table = Ellipse.new(rx: 400, ry: 30).arc_length_table
    [0.0, 0.01, 0.2499, 0.25, 0.2501, 0.5, 0.74, 0.99].each do |t|
      assert_in_delta t, table.param_at(table.length_at(t)), 1e-9
    end
  end

  def test_length_at_is_monotonic_and_ends_at_length
    table = Ellipse.new(rx: 400, ry: 30).arc_length_table
    previous = -1.0
    (0..1000).each do |i|
      s = table.length_at(i / 1000.0)
      assert_operator s, :>, previous
      previous = s
    end
    assert_in_delta table.length, table.length_at(1.0)
    assert_equal 0.0, table.length_at(0.0)
  end

  # The test that separates correct output from broken output: points spaced
  # by equal arc length must sit at (nearly) equal chord distances, where
  # equal parametric-angle steps visibly bunch near the ends of the major axis.
  def test_equal_arc_length_steps_give_uniform_spacing_where_equal_angles_do_not
    ellipse = Ellipse.new(rx: 200, ry: 80)
    count = 40

    by_length = ellipse.spine.sample(count)
    by_angle = Array.new(count) { |i| ellipse.point(i / count.to_f) }

    chord_ratio = lambda do |points|
      chords = (points + [points.first]).each_cons(2).map { |a, b| a.distance_to(b) }
      chords.max / chords.min
    end

    assert_operator chord_ratio.(by_length), :<, 1.05
    assert_operator chord_ratio.(by_angle), :>, 2.0
  end

  def test_inverse_lookup_is_accurate_far_from_table_nodes
    # A coarse table forces the Newton polish to do the real work.
    piece = Ellipse.new(rx: 300, ry: 50)
    coarse = ArcLengthTable.new(piece, 24)
    fine = ArcLengthTable.new(piece, 512)
    assert_in_delta fine.length, coarse.length, 1e-6
    [0.1, 0.37, 0.5, 0.8].each do |fraction|
      s = fine.length * fraction
      assert_in_delta fine.param_at(s), coarse.param_at(s), 1e-8
    end
  end

  def test_out_of_range_lengths_clamp
    table = Ellipse.circle(10).arc_length_table
    assert_equal 0.0, table.param_at(-5)
    assert_equal 1.0, table.param_at(table.length + 5)
  end
end
