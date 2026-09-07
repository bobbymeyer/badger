# frozen_string_literal: true

require_relative "acceptance_helper"

# Le Dive: fit to width at y. A stack of lines in a rounded lozenge, each
# taking half the chord at its own height with its height fixed, so widths
# follow the shape within a range and the I stays a bar.
class LeDiveAcceptanceTest < Minitest::Test
  include Badger::Geometry
  include AcceptanceHelper

  def setup
    super
    @container, @output = build(:le_dive)
    @field = @container.regions.first
    @lines = %w[LE D I V E 37].map { |name| node(@container, name) }
  end

  def test_the_badge_is_the_reference_size_with_rounded_points
    min, max = @output.ink_bounds
    assert_in_delta 281, max.x - min.x, 3
    assert_in_delta 844, max.y - min.y, 4
    assert_empty @container.spine.corners, "the points are filleted"
  end

  def test_every_line_keeps_its_fixed_height
    heights = @lines.map { |n| n.bounds.then { |a, b| b.y - a.y } }
    assert_in_delta 45, heights[0], 1e-6
    heights[1..4].each { |h| assert_in_delta 105, h, 1e-6 }
    assert_in_delta 43, heights[5], 1e-6
  end

  def test_widths_follow_the_chord_at_each_height_within_the_range
    @lines.each do |n|
      min, max = n.bounds
      cy = (min.y + max.y) / 2
      chord = @field.chord_at_y(cy)
      half = (chord[1] - chord[0]) / 2
      width = max.x - min.x
      setting = n.child
      if setting.stretch >= 2.2 - 1e-6 || setting.stretch <= 0.6 + 1e-6 || n.name == "I"
        assert_operator width, :<=, half + 1e-6, "#{n.name}: at the range's edge, no wider than the half chord"
      else
        assert_in_delta half, width, 1e-6, "#{n.name} takes half the chord"
      end
      assert_in_delta (chord[0] + chord[1]) / 2, (min.x + max.x) / 2, 1e-6, "#{n.name} is centred on its chord"
    end
    i = node(@container, "I")
    v = node(@container, "V")
    assert_operator i.bounds.then { |a, b| b.x - a.x }, :<, v.bounds.then { |a, b| b.x - a.x } / 2, "the I stays a bar"
  end

  def test_lines_stack_without_touching_and_stay_inside
    ys = @lines.map(&:bounds)
    ys.each_cons(2) { |(_, above_max), (below_min, _)| assert_operator above_max.y, :<, below_min.y }
    @lines.each do |n|
      ink_points(n.child.path).each { |q| assert within?(@field, q), "#{n.name}: ink at #{q} leaves the field" }
    end
  end

  def test_two_slots
    assert_equal %w[ground ink], @output.slots.map(&:name)
    assert_equal :container, @output.pieces.first.kind
  end
end
