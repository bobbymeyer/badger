# frozen_string_literal: true

require "test_helper"

class ShapesTest < Minitest::Test
  include Badger::Geometry

  def winding(path) = Offset.signed_area(path.spine.flatten(0.05))

  def test_circle_and_ellipse_are_exact
    assert_kind_of Ellipse, Badger::Shapes.circle(40)
    e = Badger::Shapes.ellipse(60, 30, center: pt(5, 5), rotation: 0.2)
    assert_in_delta 0.2, e.rotation
    assert_point pt(5, 5), e.center
  end

  def test_rectangle_and_lozenge
    rect = Badger::Shapes.rectangle(200, 100)
    assert_equal [pt(-100, -50), pt(100, 50)], rect.bounds
    assert_in_delta 20_000, rect.area
    loz = Badger::Shapes.lozenge(200, 100, center: pt(10, 10))
    assert_equal [pt(-90, -40), pt(110, 60)], loz.bounds
    assert_in_delta 10_000, loz.area
    assert_equal 4, loz.spine.corners.size
  end

  def test_rounded_rectangle_area_and_cap
    r = Badger::Shapes.rounded_rectangle(200, 100, radius: 20)
    assert_equal [pt(-100, -50), pt(100, 50)], r.bounds
    assert_in_delta 20_000 - (4 - Math::PI) * 400, r.area, 2
    assert_empty r.spine.corners
    pill = Badger::Shapes.rounded_rectangle(200, 100, radius: 500)
    assert_in_delta 100 * 100 + Math::PI * 2500, pill.area, 12 # four-cubic circle, flattened
    assert_raises(ArgumentError) { Badger::Shapes.rounded_rectangle(10, 10, radius: 0) }
  end

  def test_shield_bounds_and_curve_range
    chevron = Badger::Shapes.shield(200, 300, shoulder: 0.5, curve: 0)
    assert_equal [pt(-100, -150), pt(100, 150)], chevron.bounds
    assert_in_delta 200 * 150 + 200 * 150 / 2.0, chevron.area, 0.5
    full = Badger::Shapes.shield(200, 300, shoulder: 0.5, curve: 1)
    assert_operator full.area, :>, chevron.area
    assert_equal [pt(-100, -150), pt(100, 150)], full.bounds
    assert_point pt(0, 150), full.subpaths.first.segments[2].end_point # the two curves meet at the point
    assert_raises(ArgumentError) { Badger::Shapes.shield(10, 10, curve: 2) }
    assert_raises(ArgumentError) { Badger::Shapes.shield(10, 10, shoulder: -1) }
  end

  def test_all_primitives_wind_the_same_way_and_make_containers
    shapes = [Badger::Shapes.rectangle(10, 10), Badger::Shapes.lozenge(10, 10),
              Badger::Shapes.rounded_rectangle(10, 10, radius: 2), Badger::Shapes.shield(10, 10),
              Badger::Shapes.circle(5).to_path]
    signs = shapes.map { |s| winding(s).positive? }
    assert_equal [signs.first] * shapes.size, signs
    shapes.each { |s| assert Badger::Container.new(s).spine.closed? }
    assert Badger::Container.new(Badger::Shapes.ellipse(5, 3)).spine.closed?
  end
end

class IllustrationTest < Minitest::Test
  include Badger::Geometry

  MONO = File.expand_path("fixtures/mono.svg", __dir__)
  MULTI = File.expand_path("fixtures/multi.svg", __dir__)

  def mono = (@mono ||= Badger::Illustration.from_file(MONO, name: "star"))
  def multi = (@multi ||= Badger::Illustration.from_file(MULTI))

  def test_ink_bounds_not_the_viewbox
    assert_equal [0.0, 0.0, 400.0, 400.0], mono.view_box
    min, max = mono.bounds
    assert_point pt(100, 100), min
    assert_point pt(300, 300), max
    assert_in_delta 200, mono.ink_width
  end

  def test_group_transforms_apply_and_unfilled_geometry_is_ignored
    assert_equal 2, mono.path.subpaths.size, "the star and the rect; not the stroked circle, not the defs"
    assert_point pt(190, 290), mono.path.subpaths.last.start_point
  end

  def test_fills_are_stripped_to_one_slot_case_insensitively
    assert mono.monochrome?
    assert_equal ["#1d2a44"], mono.fills
    refute_match(/fill/, mono.path.to_d)
  end

  def test_multicolor_artwork_is_detected_and_keeps_its_markup
    assert multi.multicolor?
    assert_equal 3, multi.fills.size
    assert_includes multi.markup, "<polygon"
    assert_equal 3, multi.path.subpaths.size
  end

  def test_style_fill_inheritance_and_rotate_about_a_point
    fills = multi.fills
    assert_includes fills, "#b8452f"
    ellipse = multi.path.subpaths.last.spine
    min, max = ellipse.to_path.bounds
    assert_in_delta 50, (min.x + max.x) / 2, 0.5
    assert_in_delta 70, (min.y + max.y) / 2, 0.5
    assert_operator max.x - min.x, :<, 80, "rotated: narrower than the unrotated width"
  end

  def test_uniform_scaling_only
    half = mono.scale_by(0.5)
    assert_in_delta 100, half.ink_width
    assert_includes half.markup, "<g transform=\"matrix(0.5 0 0 0.5 0 0)\">"
    assert_raises(ArgumentError) { mono.scale_by(0) }
    assert_raises(ArgumentError) { Badger::Fit.new(axes: :both, stretch: 0.5..2).to_box(mono, width: 10, height: 10) }
    fitted = Badger::Fit.new(policy: :contain, max_size: 1000).to_box(mono, width: 50, height: 500)
    assert_in_delta 50, fitted.run.ink_width
  end

  def test_placement_uses_ink_bounds
    parent = Badger::Container.new(Badger::Shapes.rectangle(400, 400))
    node = parent.place(mono, at: Badger::Locator.centroid, align: :center)
    assert_equal :illustration, node.kind
    assert_point pt(0, 0), (node.bounds[0] + node.bounds[1]) / 2, 1e-6
    output = Badger.render(parent)
    piece = output.pieces.last
    assert_equal :illustration, piece.kind
    refute piece.passthrough?
    assert_equal 1, piece.rank
    assert_includes output.to_svg, 'data-kind="illustration"'
  end

  def test_multicolor_passes_through_with_its_transform_and_no_slot
    parent = Badger::Container.new(Badger::Shapes.rectangle(400, 400))
    parent.place(multi, at: Badger::Locator.axial(1, 1), align: :bottom_right)
    output = Badger.render(parent, world: Affine.translate(500, 500))
    piece = output.pieces.last
    assert piece.passthrough?
    assert_nil piece.rank
    assert_equal 1, output.slots.size, "pass-through artwork takes no slot"
    assert_equal [0], output.slots.map(&:given)
    svg = output.to_svg
    assert_includes svg, 'data-passthrough="true"'
    assert_match(/<g transform="matrix\(1 0 0 1 [\d.]+ [\d.]+\)"[^>]*><g style=.fill:#b8452f.>/, svg)
    assert_equal true, output.to_h[:pieces].last[:passthrough]
  end

  def test_an_illustration_can_be_a_container_with_a_spine_to_follow
    container = mono.to_container(name: "star")
    assert_equal "star", container.name
    refute container.visible?
    assert_equal 1, container.nodes.size
    assert_in_delta mono.spine.length, container.length
    band = container.band(outer: 10, width: 8)
    follow = Badger::Follow.new(band.middle, [10] * 5)
    assert follow.fits?
  end

  def test_rejects_non_svg_and_empty_artwork
    assert_raises(ArgumentError) { Badger::Illustration.new("<html></html>") }
    assert_raises(ArgumentError) { Badger::Illustration.new('<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1" fill="none"/></svg>') }
  end
end
