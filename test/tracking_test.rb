# frozen_string_literal: true

require "test_helper"

class TrackingTest < Minitest::Test
  def test_scales_with_radius_so_rings_agree_angularly
    inner = Badger::Tracking.at_radius(4, set_radius: 100, radius: 80)
    outer = Badger::Tracking.at_radius(4, set_radius: 100, radius: 120)
    assert_in_delta 3.2, inner
    assert_in_delta 4.8, outer
    assert_in_delta Badger::Tracking.to_angle(inner, 80), Badger::Tracking.to_angle(outer, 120)
  end

  def test_angle_conversions_round_trip
    angle = Badger::Tracking.to_angle(6, 150)
    assert_in_delta 6, Badger::Tracking.from_angle(angle, 150)
  end

  def test_rejects_a_zero_set_radius
    assert_raises(ArgumentError) { Badger::Tracking.at_radius(4, set_radius: 0, radius: 1) }
  end
end
