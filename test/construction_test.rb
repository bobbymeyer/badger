# frozen_string_literal: true

require_relative "acceptance/acceptance_helper"

# What an editor needs from a render that a consumer does not: the way back
# from every piece to the document entry that made it, the construction the
# pieces were built on, and what went wrong without failing.
class ConstructionTest < Minitest::Test
  include AcceptanceHelper

  def test_every_piece_carries_the_address_of_its_entry
    _container, output = build(:stockholm)

    assert_equal %w[regions[0] type[0] type[1] children[0].type[0] children[0].type[1]], output.pieces.map(&:address)
    assert_includes output.to_svg, 'data-address="type[0]"'
    assert_includes output.to_svg, 'data-address="children[0].type[1]"'
    assert_equal "type[0]", output.to_h[:pieces][1][:address]
  end

  def test_the_construction_covers_the_whole_tree_visible_or_not
    container, output = build(:stockholm)
    kinds = output.construction.map { |c| [c[:kind], c[:address]] }

    # the invisible root, its band, the two follows, the invisible setting line and its two settings
    assert_equal [["container", ""], ["band", "regions[0]"], ["follow", "type[0]"], ["follow", "type[1]"],
                  ["container", "children[0]"], ["type", "children[0].type[0]"], ["type", "children[0].type[1]"]], kinds
    root = output.construction.first
    refute root[:visible]
    assert_match(/\AM /, root[:d])
    assert_in_delta 0.0, root[:centroid][:x], 1.0
    band = output.construction[1]
    assert_equal 153.0, band[:width]
    assert_match(/\AM /, band[:outer_d])
    assert_match(/\AM /, band[:inner_d])
    nineteen = output.construction[-2]
    assert nineteen[:anchor], "a placed child says where it was put"
    # axial [0.098, 0.5] of a 782-wide setting line centred on the badge
    assert_in_delta(-391.0 + 0.098 * 782.0, nineteen[:anchor][:x], 1.0)
    assert_in_delta 0.0, nineteen[:anchor][:y], 1.0
    assert container.nodes.last.child.is_a?(Badger::Container)
  end

  def test_a_follow_says_its_sweep_as_degrees_and_its_run_as_points
    _container, output = build(:stockholm)
    top = output.construction.find { |c| c[:address] == "type[0]" }

    assert_in_delta 202.0, top[:sweep][:from][:degrees], 1.0
    assert_in_delta 338.0, top[:sweep][:to][:degrees], 1.0
    assert_equal "justify", top[:align]
    assert top[:fits]
    assert_equal 9, top[:letters].size
    assert_match(/\AM /, top[:d])
    assert top[:run][:from][:x] < top[:run][:to][:x], "STOCKHOLM reads left to right over the top"
    # the fixture face is wide, so justifying STOCKHOLM into its sweep squeezes it: a warning, not a failure
    assert output.warnings.all? { |w| w[:address] && w[:message] }
  end

  def test_a_fitted_line_says_the_chord_it_was_measured_against
    _container, output = build(:le_dive)
    le = output.construction.find { |c| c[:address] == "type[0]" }

    assert_equal "type", le[:kind]
    assert_match(/\AM -?[\d.]+ -311 L -?[\d.]+ -311\z/, le[:chord])
  end

  def test_a_run_squeezed_into_its_sweep_is_a_warning_with_an_address
    doc = Badger::References.stockholm(font: "badger-test")
    doc["type"][0]["text"] = "STOCKHOLM STOCKHOLM STOCKHOLM"
    output = Badger.render(Badger::Spec.build(doc))

    warning = output.warnings.find { |w| w[:address] == "type[0]" }
    assert warning, "a justified run longer than its sweep collides"
    assert_match(/letters collide/, warning[:message])
    assert_equal warning, output.to_h[:warnings].first
  end
end
