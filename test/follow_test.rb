# frozen_string_literal: true

require "test_helper"

class FollowTest < Minitest::Test
  include Badger::Geometry

  def line(length = 100) = Path.polyline([pt(0, 0), pt(length, 0)]).spine

  def test_places_advances_end_to_end_with_tracking
    follow = Badger::Follow.new(line, [10, 20, 30], tracking: 5)
    assert_equal 70.0, follow.run_length
    assert follow.fits?
    starts = follow.placements.map(&:start)
    assert_equal [0.0, 15.0, 40.0], starts
    assert_equal [5.0, 25.0, 55.0], follow.placements.map(&:center)
    assert_point pt(25, 0), follow.placements[1].point
    assert_in_delta 0.0, follow.placements[1].degrees
    assert_point pt(0, -1), follow.placements[1].normal
  end

  def test_alignment_within_the_sweep
    advances = [10, 10]
    centered = Badger::Follow.new(line, advances, start: 10, sweep: 60, align: :center)
    assert_equal 30.0, centered.origin
    ended = Badger::Follow.new(line, advances, start: 10, sweep: 60, align: :end)
    assert_equal 50.0, ended.origin
    assert_equal 70.0, ended.placements.last.end
  end

  def test_justify_solves_tracking_to_fill_the_sweep
    follow = Badger::Follow.new(line, [10, 20, 30], sweep: 100, align: :justify)
    assert_equal 20.0, follow.tracking
    assert_in_delta 100.0, follow.run_length
    assert_in_delta 100.0, follow.placements.last.end
    assert_equal 0.0, Badger::Follow.tracking_to_sweep([50], 100)
  end

  def test_overflow_is_reported_not_hidden
    follow = Badger::Follow.new(line(50), [30, 30])
    refute follow.fits?
    assert_in_delta 10.0, follow.overflow
    assert_equal 2, follow.placements.size
  end

  def test_glyphs_follow_the_top_of_an_ellipse_reading_left_to_right
    ellipse = Ellipse.new(rx: 200, ry: 100)
    spine = ellipse.spine
    start = spine.length_at(0, ellipse.param_at_polar(Math::PI))       # left end
    sweep = spine.length / 2                                             # to the right end, over the top
    follow = Badger::Follow.new(spine, [40] * 5, start: start, sweep: sweep, align: :center)
    middle = follow.placements[2]
    assert_point pt(0, -100), middle.point, 1e-6
    assert_in_delta 0.0, middle.degrees, 1e-6
    assert_point pt(0, -1), middle.normal, 1e-6
    xs = follow.placements.map { |p| p.point.x }
    assert_equal xs.sort, xs, "reads left to right"
    assert follow.placements.all? { |p| p.point.y.negative? }
  end

  def test_reverse_arc_along_the_bottom
    ellipse = Ellipse.new(rx: 200, ry: 100)
    spine = ellipse.spine.reversed
    follow = Badger::Follow.new(spine, [40] * 5, start: spine.length / 2, sweep: spine.length / 2, align: :center)
    middle = follow.placements[2]
    assert_point pt(0, 100), middle.point, 1e-6
    assert_in_delta 0.0, middle.degrees, 1e-6
    assert_point pt(0, -1), middle.normal, 1e-6 # glyph tops point toward the centre
    xs = follow.placements.map { |p| p.point.x }
    assert_equal xs.sort, xs
  end

  def test_closed_spine_runs_wrap_around_the_start
    spine = Ellipse.circle(100).spine
    follow = Badger::Follow.new(spine, [20, 20], start: spine.length - 10)
    assert_point spine.point_at(0), follow.placements.first.point
    assert_point spine.point_at(20), follow.placements.last.point
  end

  def test_corner_straddling_is_flagged
    rect = Path.rect(0, 0, 100, 50).spine
    follow = Badger::Follow.new(rect, [20, 20, 20], start: 50)
    assert_equal [false, false, true], follow.placements.map(&:straddles_corner?)
  end

  def test_svg_transform
    follow = Badger::Follow.new(line, [10])
    assert_equal "translate(5 0) rotate(0) translate(-5 0)", follow.placements.first.svg_transform
  end

  def test_rejects_unknown_alignment
    assert_raises(ArgumentError) { Badger::Follow.new(line, [1], align: :middle) }
  end
end
