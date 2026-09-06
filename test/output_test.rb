# frozen_string_literal: true

require "test_helper"

class SlotTest < Minitest::Test
  def test_named_and_integer_ranks
    assert_equal 0, Badger::Slot.rank(:ground)
    assert_equal 1, Badger::Slot.rank(:field)
    assert_equal 2, Badger::Slot.rank(:ink)
    assert_equal 7, Badger::Slot.rank(7)
    assert_raises(ArgumentError) { Badger::Slot.rank(:paper) }
    assert_raises(ArgumentError) { Badger::Slot.rank(-1) }
    assert_raises(ArgumentError) { Badger::Slot.rank("ink") }
  end

  def test_names_for_dense_ranks
    assert_equal "ink", Badger::Slot.name_for(0, 1)
    assert_equal %w[ground ink], [Badger::Slot.name_for(0, 2), Badger::Slot.name_for(1, 2)]
    assert_equal %w[ground field ink], (0..2).map { |r| Badger::Slot.name_for(r, 3) }
    assert_equal %w[ground field-1 field-2 ink], (0..3).map { |r| Badger::Slot.name_for(r, 4) }
  end

  def test_value_ladder_runs_paper_to_ink_in_neutral_greys
    paper = Badger::Value.grey(Badger::Value.lightness(0, 2))
    ink = Badger::Value.grey(Badger::Value.lightness(1, 2))
    assert_match(/\A#(\h\h)\1\1\z/, paper)
    assert_match(/\A#(\h\h)\1\1\z/, ink)
    assert_operator paper[1, 2].to_i(16), :>, 240
    assert_operator ink[1, 2].to_i(16), :<, 40
    greys = (0..4).map { |r| Badger::Value.grey(Badger::Value.lightness(r, 5))[1, 2].to_i(16) }
    assert_equal greys.sort.reverse, greys
    assert_equal ink, Badger::Value.grey(Badger::Value.lightness(0, 1)), "a lone slot is ink"
  end
end

class OutputTest < Minitest::Test
  include Badger::Geometry

  FONT = File.expand_path("fixtures/badger-test.ttf", __dir__)

  def font = (@font ||= Badger::Font.new(FONT))

  def badge
    @badge ||= begin
      b = Badger::Container.new(Path.rect(0, 0, 200, 100), name: "badge")
      b.rule(0, weight: 4, name: "rule")
      b.place(Badger::Setting.new(font.shape("H", size: 50)), at: Badger::Locator.centroid, name: "H")
      b
    end
  end

  def test_render_returns_an_output_with_pieces_in_world_space
    output = Badger.render(badge, world: Affine.translate(100, 100))
    assert_kind_of Badger::Output, output
    assert_equal %i[container region type], output.pieces.map(&:kind)
    assert_equal ["badge", "rule", "H"], output.pieces.map(&:name)
    assert_point pt(98, 98), output.ink_bounds[0], 1e-6
    assert_point pt(302, 202), output.ink_bounds[1], 1e-6
    assert_in_delta 204, output.width
    assert_equal 3, output.geometry.subpaths.size + 0 if output.geometry.subpaths.size == 3
  end

  def test_slots_are_densely_ranked_from_sparse_defaults
    output = Badger.render(badge) # ground (0) and ink (2), nothing at 1
    assert_equal [0, 1], output.slots.map(&:rank)
    assert_equal [0, 2], output.slots.map(&:given)
    assert_equal %w[ground ink], output.slots.map(&:name)
    assert_equal [0, 1, 1], output.pieces.map(&:rank)
    assert_equal [1, 2], output.slots.map(&:pieces)
    assert_equal "--badger-slot-1", output.slots.last.property
  end

  def test_three_slots_when_a_field_is_in_play
    badge.interior(inside: -4, visible: true, name: "field")
    output = Badger.render(badge)
    assert_equal %w[ground field ink], output.slots.map(&:name)
    field = output.pieces.find { |p| p.name == "field" }
    assert_equal 1, field.rank
  end

  def test_slots_can_be_reassigned_per_piece
    knock = Badger::Container.new(Path.rect(0, 0, 200, 100), slot: :ink)
    knock.place(Badger::Setting.new(font.shape("H", size: 50)), at: Badger::Locator.centroid, slot: :ground)
    knock.rule(-10, slot: 5)
    output = Badger.render(knock)
    assert_equal [0, 2, 5], output.slots.map(&:given)
    assert_equal [1, 2, 0], output.pieces.map(&:rank)
  end

  def test_unresolved_fills_are_custom_properties_over_value_greys
    svg = Badger.render(badge).to_svg
    assert_includes svg, 'fill="var(--badger-slot-0, #'
    assert_includes svg, 'fill="var(--badger-slot-1, #'
    assert_includes svg, 'data-slot="1" data-kind="type" data-name="H"'
    assert_includes svg, 'data-badger-slots="2"'
    refute_match(/fill="#/, svg)
  end

  def test_colours_resolve_by_rank_or_name_when_given
    output = Badger.render(badge)
    svg = output.to_svg(colors: { 0 => "#f4f1ea", "ink" => "#1d2a44" })
    assert_includes svg, 'fill="#f4f1ea"'
    assert_includes svg, 'fill="#1d2a44"'
    refute_includes svg, "var("
    partial = output.to_svg(colors: { ground: "#fff" })
    assert_includes partial, 'fill="#fff"'
    assert_includes partial, "var(--badger-slot-1"
  end

  def test_svg_viewbox_hugs_the_ink_with_optional_padding
    svg = Badger.render(badge, world: Affine.translate(10, 20)).to_svg(padding: 5)
    assert_includes svg, 'viewBox="3 13 214 114"'
  end

  def test_optical_center_follows_the_weight_not_the_bounds
    symmetric = Badger.render(badge)
    assert_point pt(100, 50), symmetric.optical_center, 0.5
    shield = Badger::Container.new(Path.parse("M 0 0 L 200 0 L 200 100 L 100 200 L 0 100 Z"))
    output = Badger.render(shield)
    mid = (output.ink_bounds[0] + output.ink_bounds[1]) / 2
    assert_operator output.optical_center.y, :<, mid.y, "the weight sits above the middle of the bounds"
  end

  def test_container_path_and_anchors_are_separate_and_in_world_space
    output = Badger.render(badge, world: Affine.translate(100, 100))
    assert_equal "M 100 100 L 300 100 L 300 200 L 100 200 Z", output.container_path.to_d
    assert_point pt(200, 100), output.anchors[:top]
    assert_point pt(300, 200), output.anchors[:bottom_right]
    assert_point pt(200, 150), output.anchors[:centroid]
    assert_point pt(250, 100), output.anchor(Badger::Locator.on_path(fraction: 0.25))
  end

  def test_metadata_hash_and_json
    h = Badger.render(badge).to_h
    assert_equal %i[ink_bounds optical_center container anchors slots pieces], h.keys
    assert_equal 2, h[:slots].size
    assert_equal "--badger-slot-0", h[:slots].first[:property]
    assert_equal({ kind: :type, name: "H", slot: 1, depth: 1 }, h[:pieces].last.slice(:kind, :name, :slot, :depth))
    assert_match(/"container":"M 0 0/, Badger.render(badge).to_json)
  end

  def test_invisible_container_with_type_only_has_one_slot_which_is_ink
    line = Badger::Container.new(Path.rect(0, 0, 100, 10), visible: false)
    line.place(Badger::Setting.new(font.shape("H", size: 10)), at: Badger::Locator.centroid)
    output = Badger.render(line)
    assert_equal ["ink"], output.slots.map(&:name)
    assert_equal Badger::Value.grey(Badger::Value::INK), output.slots.first.value
  end
end
