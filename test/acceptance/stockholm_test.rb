# frozen_string_literal: true

require "test_helper"
require "yaml"

# The handoff's acceptance test, as far as it can be run without the
# reference image: Stockholm Stadion 1912 exercises the elliptical spine,
# the annulus, cap-height-equals-band-width fitting and polar-anchored
# fixed type in one document, with the setting line as an invisible
# container. Each of those is asserted here geometrically. Whether the
# result matches the reference is the half only an eye can judge.
class StockholmAcceptanceTest < Minitest::Test
  include Badger::Geometry

  FIXTURES = File.expand_path("../fixtures", __dir__)
  RX = 260.0
  RY = 170.0
  BAND_OUTER = -8.0
  BAND_WIDTH = 40.0
  INSET = 7.0

  DOCUMENT = YAML.safe_load(<<~YAML)
    name: Stockholm Stadion
    shape: { kind: ellipse, rx: 260, ry: 170 }
    regions:
      - { kind: rule, name: outer, distance: 0, weight: 5 }
      - { kind: band, name: ring, outer: -8, width: 40 }
      - { kind: rule, name: inner, distance: -50, weight: 2 }
      - { kind: interior, name: field, inside: -52 }
    type:
      - { mode: follow, text: HOHOHOHOHOHOH, font: badger-test, region: ring, inset: 7, sweep: top, align: justify, name: ring top }
      - { mode: follow, text: "IHIH", font: badger-test, region: ring, from: outer, inset: 7, sweep: bottom, tracking: 12, name: ring bottom }
      - { mode: fixed, text: HI, font: badger-test, size: 14, at: { polar: { angle: 180, radius: 168 } }, align: left, name: est }
      - { mode: fixed, text: IH, font: badger-test, size: 14, at: { polar: { angle: 0, radius: 168 } }, align: right, name: year }
    children:
      - name: setting line
        shape: { kind: rectangle, width: 300, height: 1 }
        visible: false
        at: { axial: [0.5, 0.5] }
        type:
          - { mode: fixed, text: HHH, font: badger-test, size: 40, at: { axial: [0.5, 0] }, align: bottom, name: motto }
  YAML

  def setup
    Badger::Fonts.reset!.add_directory(FIXTURES)
    @container = Badger::Spec.build(DOCUMENT)
    @output = Badger.render(@container)
    @ring = @container.regions[1]
    @top = @container.nodes.find { |n| n.name == "ring top" }.child
    @bottom = @container.nodes.find { |n| n.name == "ring bottom" }.child
  end

  def teardown = Badger::Fonts.reset!

  # --- the elliptical spine --------------------------------------------------

  def test_ring_type_sits_on_the_elliptical_baseline_at_equal_arc_length
    # every glyph centre is the baseline's offset in from the container ellipse
    ellipse = Ellipse.new(rx: RX, ry: RY)
    dense = (0...4000).map { |i| ellipse.point(i / 4000.0) }
    expected = -(BAND_OUTER - BAND_WIDTH + INSET)
    @top.placements.each do |p|
      nearest = dense.map { |q| q.distance_to(p.point) }.min
      assert_in_delta expected, nearest, 0.3, "a glyph centre sits #{nearest} in from the ellipse, not #{expected}"
    end
    gaps = @top.placements.each_cons(2).map { |a, b| b.center - a.center }
    advances = @top.advances
    gaps.each_with_index do |gap, i|
      assert_in_delta (advances[i] + advances[i + 1]) / 2 + @top.tracking, gap, 1e-6
    end
  end

  def test_equal_arc_length_is_not_equal_angle
    # the spine is an ellipse: equal steps along it are not equal steps in angle,
    # which is what a uniform-angle distribution would have got wrong
    center = @container.centroid
    angles = @top.placements.map { |p| Math.atan2(p.point.y - center.y, p.point.x - center.x) }
    steps = angles.each_cons(2).map { |a, b| (b - a).abs }
    assert_operator steps.max / steps.min, :>, 1.3
  end

  # --- the annulus -----------------------------------------------------------

  def test_ring_type_stays_inside_the_band
    outer = Badger::Regions::Interior.new(@container, inside: BAND_OUTER, visible: false, name: nil)
    inner = Badger::Regions::Interior.new(@container, inside: BAND_OUTER - BAND_WIDTH, visible: false, name: nil)
    [@top, @bottom].each do |follow|
      follow.path.spines.each do |contour|
        contour.flatten(0.5).each do |q|
          assert within?(outer, q), "ink at #{q} is outside the band's outer edge"
          refute within?(inner, q), "ink at #{q} is inside the band's inner edge"
        end
      end
    end
  end

  def test_the_band_itself_is_an_annulus
    assert_equal 2, @ring.path.subpaths.size
    assert_in_delta BAND_WIDTH, @ring.width
  end

  # --- cap height equals band width ------------------------------------------

  def test_cap_height_equals_the_band_width_less_the_insets
    assert_in_delta BAND_WIDTH - 2 * INSET, @top.run.cap_height, 1e-6
    assert_in_delta BAND_WIDTH - 2 * INSET, @bottom.run.cap_height, 1e-6
  end

  def test_the_top_ring_is_justified_across_the_top_and_reads_left_to_right
    assert @top.fits?
    assert_in_delta @top.sweep, @top.run_length, 1e-6
    xs = @top.placements.map { |p| p.point.x }
    assert_equal xs.sort, xs
    assert @top.placements.all? { |p| p.point.y < 0 }
    assert @top.placements.all? { |p| p.normal.y < 0 }, "glyph tops point outward on the top arc"
  end

  def test_the_bottom_ring_reads_left_to_right_with_tops_toward_the_centre
    xs = @bottom.placements.map { |p| p.point.x }
    assert_equal xs.sort, xs
    assert @bottom.placements.all? { |p| p.point.y > 0 }
    assert @bottom.placements.all? { |p| p.normal.y < 0 }, "glyph tops point toward the centre on the bottom arc"
  end

  # --- polar-anchored fixed type ---------------------------------------------

  def test_the_pair_holds_its_outer_edges_on_the_polar_locators
    est = @container.nodes.find { |n| n.name == "est" }
    year = @container.nodes.find { |n| n.name == "year" }
    assert_in_delta(-168, est.bounds[0].x, 1e-6)
    assert_in_delta 168, year.bounds[1].x, 1e-6
    assert_equal 14.0, est.child.size, "fixed type keeps its size; the region only positions it"
  end

  # --- the setting line ------------------------------------------------------

  def test_the_setting_line_is_invisible_and_still_anchors
    line = @container.nodes.find { |n| n.name == "setting line" }
    refute line.child.visible?
    motto = @output.pieces.find { |p| p.name == "motto" }
    assert motto, "the motto is drawn"
    refute @output.pieces.any? { |p| p.kind == :container && p.depth == 1 }, "the setting line is not"
    assert_in_delta(-0.5, motto.path.bounds[1].y, 1e-6, "the motto's baseline sits on the setting line's top edge, at the badge's centre")
  end

  # --- the whole image -------------------------------------------------------

  def test_the_badge_is_two_slots_and_stands_alone_unresolved
    assert_equal %w[ground ink], @output.slots.map(&:name)
    svg = @output.to_svg
    assert_includes svg, "var(--badger-slot-0"
    refute_match(/fill="#/, svg)
    assert_equal 8, @output.pieces.size
  end

  private

  def within?(interior, point)
    interior.spans_at_y(point.y).any? { |a, b| a - 1e-6 <= point.x && point.x <= b + 1e-6 }
  end
end
