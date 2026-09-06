# frozen_string_literal: true

require "test_helper"

class BooleansTest < Minitest::Test
  include Badger::Geometry

  def square(x, y, side) = Path.rect(x, y, side, side)

  def test_union_merges_overlapping_shapes
    merged = Badger::Booleans.union(square(0, 0, 100), square(50, 50, 100))
    assert_equal 1, merged.subpaths.size
    assert_in_delta 17_500, merged.area
    assert_equal [pt(0, 0), pt(150, 150)], merged.bounds
  end

  def test_union_accepts_arrays_and_multi_subpath_paths
    merged = Badger::Booleans.union([square(0, 0, 100)], square(50, 50, 100) + square(300, 300, 10))
    assert_equal 2, merged.subpaths.size
    assert_in_delta 17_600, merged.area
  end

  def test_difference_cuts_a_hole_with_opposite_winding
    cut = Badger::Booleans.difference(square(0, 0, 100), square(25, 25, 50))
    assert_equal 2, cut.subpaths.size
    assert_in_delta 7_500, cut.area
    windings = cut.subpaths.map { |s| Offset.signed_area(s.spine.flatten(0.1)) }
    assert_operator windings[0] * windings[1], :<, 0
  end

  def test_intersection_and_xor
    assert_in_delta 2_500, Badger::Booleans.intersection(square(0, 0, 100), square(50, 50, 100)).area
    assert_in_delta 15_000, Badger::Booleans.xor(square(0, 0, 100), square(50, 50, 100)).area
  end

  def test_empty_results_are_empty_paths
    assert Badger::Booleans.intersection(square(0, 0, 10), square(50, 50, 10)).empty?
  end

  def test_expand_grows_with_round_joins_and_shrinks_with_negative_distance
    grown = Badger::Booleans.expand(square(0, 0, 100), 10)
    assert_in_delta 10_000 + 4 * 100 * 10 + Math::PI * 100, grown.area, 5
    assert_point pt(-10, -10), grown.bounds[0], 0.01
    shrunk = Badger::Booleans.expand(square(0, 0, 100), -10)
    assert_in_delta 6_400, shrunk.area, 1
    assert_point pt(10, 10), shrunk.bounds[0], 0.01
    assert_in_delta 10_000, Badger::Booleans.expand(square(0, 0, 100), 0).area
  end

  def test_expand_unions_first
    grown = Badger::Booleans.expand([square(0, 0, 100), square(50, 50, 100)], 5)
    assert_equal 1, grown.subpaths.size
    assert_operator grown.area, :>, 17_500
  end

  def test_union_resolves_overlapping_glyphs
    font = Badger::Font.new(File.expand_path("fixtures/badger-test.ttf", __dir__))
    line = Path.polyline([pt(0, 0), pt(500, 0)]).spine
    overlapping = Badger::Follow.new(line, font.shape("II", size: 100), tracking: -25) # I ink is 10 wide, pens 0 and 5
    assert_equal 2, overlapping.path.subpaths.size
    unioned = Badger::Booleans.union(overlapping.path)
    assert_equal 1, unioned.subpaths.size
    assert_in_delta 15 * 70, unioned.area
  end
end

class EffectsTest < Minitest::Test
  include Badger::Geometry

  FONT = File.expand_path("fixtures/badger-test.ttf", __dir__)

  def font = (@font ||= Badger::Font.new(FONT))

  def test_knockout_subtracts_type_from_a_region
    field = Badger::Container.new(Path.rect(0, 0, 300, 200)).interior(visible: true)
    setting = Badger::Setting.new(font.shape("H", size: 100), Affine.translate(100, 150)) # ink 60 x 70
    knocked = Badger::Effects.knockout(field.path, setting.path)
    assert_in_delta 60_000 - 4_200, knocked.area
    assert_equal 2, knocked.subpaths.size
  end

  def test_offset_stroke_is_a_ring_around_the_union
    square = Path.rect(0, 0, 100, 100)
    ring = Badger::Effects.offset_stroke(square, 6)
    assert_in_delta 4 * 100 * 6 + Math::PI * 36, ring.area, 3
    assert_equal 2, ring.subpaths.size
    assert_raises(ArgumentError) { Badger::Effects.offset_stroke(square, 0) }
  end

  def test_plate_is_the_expanded_union
    plate = Badger::Effects.plate([Path.rect(0, 0, 100, 20), Path.rect(0, 30, 100, 20)], 8)
    assert_equal 1, plate.subpaths.size, "an 8 offset bridges a 10 gap into one plate"
    assert_point pt(-8, -8), plate.bounds[0], 0.01
  end
end

class BlockTest < Minitest::Test
  include Badger::Geometry

  FONT = File.expand_path("fixtures/badger-test.ttf", __dir__)

  def font = (@font ||= Badger::Font.new(FONT))
  def touching = [Path.rect(0, 0, 100, 40), Path.rect(0, 40, 100, 40)]

  def test_line_scope_keeps_a_seam_and_block_scope_removes_it
    per_line = Badger::Block.new(touching, union: :line)
    assert_equal 2, per_line.paths.size
    assert_equal 2, per_line.path.subpaths.size
    whole = Badger::Block.new(touching, union: :block)
    assert_equal 1, whole.paths.size
    assert_equal 1, whole.path.subpaths.size
    assert_in_delta 8_000, whole.path.area
  end

  def test_stack_positions_lines_on_ink_bounds
    lines = [font.shape("HH", size: 100), font.shape("I", size: 50)].map { |run| Badger::Setting.new(run) }
    block = Badger::Block.stack(lines, gap: 10, align: :center)
    first, second = block.lines.map(&:ink_bounds)
    assert_in_delta 0, first[1].y
    assert_in_delta(-70, first[0].y)
    assert_in_delta 10, second[0].y, 1e-9
    assert_in_delta 45, second[1].y, 1e-9
    assert_in_delta 0, (first[0].x + first[1].x) / 2, 1e-9
    assert_in_delta 0, (second[0].x + second[1].x) / 2, 1e-9
    assert_in_delta 120, block.bounds.then { |a, b| b.x - a.x }
  end

  def test_stack_left_and_right_alignment
    lines = [font.shape("HH", size: 100), font.shape("I", size: 100)].map { |run| Badger::Setting.new(run) }
    left = Badger::Block.stack(lines, gap: 5, align: :left)
    assert left.lines.all? { |l| l.ink_bounds[0].x.abs < 1e-9 }
    right = Badger::Block.stack(lines, gap: 5, align: :right)
    assert right.lines.all? { |l| (l.ink_bounds[1].x - 120).abs < 1e-9 }
  end

  def test_block_is_placeable_in_the_tree
    block = Badger::Block.new(touching, union: :block)
    parent = Badger::Container.new(Path.rect(0, 0, 400, 400))
    node = parent.place(block, at: Badger::Locator.centroid, align: :center)
    assert_equal :type, node.kind
    assert_point pt(200, 200), (node.bounds[0] + node.bounds[1]) / 2
  end

  def test_validation
    assert_raises(ArgumentError) { Badger::Block.new(touching, union: :page) }
    assert_raises(ArgumentError) { Badger::Block.new([]) }
    assert_raises(ArgumentError) { Badger::Block.stack([], gap: 1, align: :justify) }
  end
end
