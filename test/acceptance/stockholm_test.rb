# frozen_string_literal: true

require_relative "acceptance_helper"

# Stockholm Stadion 1912: the elliptical spine (here the reference's actual
# superellipse), the annulus, cap height equal to the band width, fixed type
# on an invisible setting line, all in one image.
class StockholmAcceptanceTest < Minitest::Test
  include Badger::Geometry
  include AcceptanceHelper

  WIDTH = 782.0
  HEIGHT = 952.0
  BAND = 153.0
  INSET = 12.0

  def setup
    super
    @container, @output = build(:stockholm)
    @ring = @container.regions.first
    @top = node(@container, "top").child
    @bottom = node(@container, "bottom").child
  end

  def test_the_badge_is_the_reference_size_and_a_ring
    min, max = @ring.bounds
    assert_in_delta WIDTH, max.x - min.x, 1.0
    assert_in_delta HEIGHT, max.y - min.y, 1.0
    refute @container.visible?, "the container is knocked out to its band"
    assert_equal 2, @ring.path.subpaths.size, "the band is an annulus"
    assert @ring.visible?
    assert_equal 0, @ring.slot, "the ring is the ground"
  end

  def test_ring_type_sits_on_the_spine_at_equal_arc_length_and_not_equal_angle
    outline = @container.spine
    dense = (0...4000).map { |i| outline.point_at(outline.length * i / 4000.0) }
    [[@top, BAND - INSET], [@bottom, INSET]].each do |follow, offset|
      follow.placements.each do |p|
        nearest = dense.map { |q| q.distance_to(p.point) }.min
        assert_in_delta offset, nearest, 0.6, "a glyph centre sits #{nearest.round(2)} in from the outline, not #{offset}"
      end
      gaps = follow.placements.each_cons(2).map { |a, b| b.center - a.center }
      gaps.each_with_index { |gap, i| assert_in_delta (follow.advances[i] + follow.advances[i + 1]) / 2 + follow.tracking, gap, 1e-6 }
      steps = follow.placements.map { |p| degrees(p.point) }.each_cons(2).map { |a, b| ((b - a + 180) % 360 - 180).abs }
      assert_operator steps.max / steps.min, :>, 1.15, "on a superellipse equal arc length is not equal angle"
    end
  end

  def test_the_sweeps_run_between_the_reference_angles
    top = @top.placements.map { |p| degrees(p.point) }
    assert_operator top.first, :>=, 202
    assert_operator top.last, :<=, 338
    assert_equal top.sort, top, "STOCKHOLM climbs from the left over the top to the right"
    assert @top.fits?
    assert_in_delta @top.sweep, @top.run_length, 1e-6, "justified across the sweep"

    bottom = @bottom.placements.map { |p| degrees(p.point) }
    assert_operator bottom.first, :<=, 170
    assert_operator bottom.last, :>=, 10
    assert_equal bottom.sort.reverse, bottom, "STADION falls from the left under the bottom to the right"
    assert @bottom.placements.all? { |p| p.normal.y < 0 }, "tops toward the centre on the bottom"
    assert @top.placements.all? { |p| p.normal.dot(p.point) > 0 }, "tops outward on the top"
  end

  def test_cap_height_equals_the_band_width_less_the_insets_and_ink_stays_in_the_band
    assert_in_delta BAND - 2 * INSET, @top.run.cap_height, 1e-6
    assert_in_delta BAND - 2 * INSET, @bottom.run.cap_height, 1e-6
    outer = Badger::Regions::Interior.new(@container, inside: 0.0, visible: false, name: nil)
    inner = Badger::Regions::Interior.new(@container, inside: -BAND, visible: false, name: nil)
    [@top, @bottom].each do |follow|
      ink_points(follow.path).each do |q|
        assert within?(outer, q), "ink at #{q} is outside the ring"
        refute within?(inner, q), "ink at #{q} is inside the hole"
      end
    end
  end

  def test_the_digits_stand_upright_on_the_setting_line_in_the_band
    line = node(@container, "setting line")
    refute line.child.visible?
    nineteen = node(line.child, "19")
    twelve = node(line.child, "12")
    [nineteen, twelve].each do |digits|
      min, max = digits.bounds
      assert_in_delta 119, max.y - min.y, 1e-6, "digits are 119 tall"
      assert_in_delta 0, (min.y + max.y) / 2, 1e-6, "centred on the setting line"
      assert_in_delta BAND / 2, WIDTH / 2 - (min.x + max.x).abs / 2, 1.0, "centred across the band"
    end
    assert_operator nineteen.bounds[1].x, :<, 0
    assert_operator twelve.bounds[0].x, :>, 0
    assert @output.pieces.none? { |p| p.kind == :container }, "neither the badge nor the setting line draws its own silhouette"
  end

  def test_two_slots_unresolved
    assert_equal %w[ground ink], @output.slots.map(&:name)
    assert_includes @output.to_svg, "var(--badger-slot-1"
  end
end
