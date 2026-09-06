# frozen_string_literal: true

require_relative "acceptance_helper"

# Giletti: fit to height at x. One word across a wide lozenge at one width
# scale; each glyph's height is the vertical chord at its own position,
# within a range, so the middle letter is tallest.
class GilettiAcceptanceTest < Minitest::Test
  include Badger::Geometry
  include AcceptanceHelper

  def setup
    super
    @container, @output = build(:giletti)
    @rule, @field = @container.regions
    @block = node(@container, "GILETTI").child
    @glyphs = @block.lines
  end

  def test_the_badge_is_the_reference_size_with_an_inset_rule
    min, max = @output.ink_bounds
    assert_in_delta 811, max.x - min.x, 1
    assert_in_delta 353, max.y - min.y, 1
    assert_equal 2, @rule.path.subpaths.size
    rmin, rmax = @rule.bounds
    assert_in_delta 751, rmax.x - rmin.x, 4, "the rule lozenge is the reference's 751 wide"
  end

  def test_each_glyph_takes_the_vertical_chord_at_its_x
    @glyphs.each_with_index do |setting, i|
      min, max = setting.ink_bounds
      # the narrowest chord across the glyph's own width, less the insets
      chords = [min.x, max.x].map { |x| @field.chord_at_x(x) }
      expected = chords.map(&:last).min - chords.map(&:first).max - 24
      height = max.y - min.y
      if setting.stretch > 0.6 + 1e-6 && setting.stretch < 2.3 - 1e-6
        assert_in_delta expected, height, 1e-6, "glyph #{i} is the chord at its x less the insets"
      else
        assert_operator height, :<=, expected + 1e-6, "glyph #{i} stopped at the range, inside the chord"
      end
      assert_in_delta 0, (min.y + max.y) / 2, 1e-6, "glyph #{i} is centred on the midline"
    end
  end

  def test_the_word_takes_one_width_scale_and_the_middle_is_tallest
    heights = @glyphs.map { |s| s.ink_bounds.then { |a, b| b.y - a.y } }
    assert_equal heights.index(heights.max), 3, "the E, in the middle, is tallest"
    assert_operator heights[0], :<, heights[2]
    assert_operator heights[6], :<, heights[4]
    scales = @glyphs.map { |s| s.affine.a.round(9) }
    assert_equal 1, scales.uniq.size, "one horizontal scale for the word: #{scales.inspect}"
    min, max = @block.bounds
    chord = @field.chord_at_y(0)
    assert_in_delta (chord[1] - chord[0]) * 0.67, max.x - min.x, 1e-6, "the word fills its share of the middle chord"
  end

  def test_the_word_stays_inside_the_rule
    @glyphs.each do |setting|
      ink_points(setting.path).each { |q| assert within?(@field, q), "ink at #{q} crosses the rule" }
    end
  end

  def test_two_slots
    assert_equal %w[ground ink], @output.slots.map(&:name)
  end
end
