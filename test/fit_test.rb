# frozen_string_literal: true

require "test_helper"

class FitTest < Minitest::Test
  include Badger::Geometry

  FONT = File.expand_path("fixtures/badger-test.ttf", __dir__)

  def font = (@font ||= Badger::Font.new(FONT))
  def hh = (@hh ||= font.shape("HH", size: 100)) # ink 0..120 wide, 70 tall
  def rect_interior = Badger::Container.new(Path.rect(0, 0, 200, 100)).interior

  def test_run_scaling_is_exact_and_needs_no_sidecar
    run = font.shape("AV", size: 100)
    doubled = run.scale_by(2)
    assert_equal 200.0, doubled.size
    assert_equal run.advances.map { |a| a * 2 }, doubled.advances
    assert_in_delta 140, doubled.cap_height
    assert_in_delta 220, doubled.ink_width # V is kerned 10 under A at this size
    assert_in_delta 50, run.at_size(50).size
    assert_raises(ArgumentError) { run.scale_by(0) }
  end

  def test_fill_by_width
    result = Badger::Fit.new(policy: :fill, axes: :width).to_box(hh, width: 240)
    assert_in_delta 2.0, result.scale_x
    assert_in_delta 1.0, result.stretch
    assert_in_delta 240, result.run.ink_width
    assert_in_delta 200, result.size
  end

  def test_fill_by_height
    result = Badger::Fit.new(policy: :fill, axes: :height).to_box(hh, height: 35)
    assert_in_delta 0.5, result.scale_x
    assert_in_delta 35, result.run.ink_height
  end

  def test_fill_both_axes_stretches_within_the_allowed_range
    fit = Badger::Fit.new(policy: :fill, axes: :both, stretch: 0.8..1.25)
    result = fit.to_box(hh, width: 240, height: 175) # kx 2, ky 2.5 -> ratio 1.25
    assert_in_delta 2.0, result.scale_x
    assert_in_delta 2.5, result.scale_y
    clamped = fit.to_box(hh, width: 240, height: 700) # ky 10 -> clamped to 1.25
    assert_in_delta 2.5, clamped.scale_y
    squashed = fit.to_box(hh, width: 240, height: 35) # ky 0.5 -> clamped to 0.8
    assert_in_delta 1.6, squashed.scale_y
  end

  def test_contain_scales_up_to_the_measure_but_not_past_max_size
    fit = Badger::Fit.new(policy: :contain, max_size: 150)
    assert_in_delta 1.5, fit.to_box(hh, width: 240).scale_x, 1e-9
    assert_in_delta 1.2, fit.to_box(hh, width: 144).scale_x, 1e-9
    assert_in_delta 0.5, fit.to_box(hh, width: 60).scale_x, 1e-9
    both = Badger::Fit.new(policy: :contain, axes: :both, max_size: 1000, stretch: 1.0..1.0).to_box(hh, width: 240, height: 70)
    assert_in_delta 1.0, both.scale_x
  end

  def test_fixed_does_not_scale
    result = Badger::Fit.new(policy: :fixed).to_box(hh, width: 999)
    assert_same hh, result.run
    assert_equal 1.0, result.scale_x
  end

  def test_argument_validation
    assert_raises(ArgumentError) { Badger::Fit.new(policy: :shrink) }
    assert_raises(ArgumentError) { Badger::Fit.new(axes: :both) }
    assert_raises(ArgumentError) { Badger::Fit.new(axes: :width, stretch: 0.9..1.1) }
    assert_raises(ArgumentError) { Badger::Fit.new(policy: :contain) }
    assert_raises(ArgumentError) { Badger::Fit.new.to_box(hh, height: 10) }
    assert_raises(Badger::Error) { Badger::Fit.new.to_box(font.shape(" ", size: 10), width: 10) }
  end

  def test_fit_to_band_sets_cap_height_to_the_band_width
    band = Badger::Container.new(Ellipse.circle(100)).band(outer: 0, width: 40)
    result = Badger::Fit.new.to_band(hh, band, inset: 5)
    assert_in_delta 30, result.run.cap_height
    assert_in_delta 30 / 0.7, result.size
    capped = Badger::Fit.new(policy: :contain, max_size: 20).to_band(hh, band)
    assert_in_delta 20, capped.size
    assert_raises(ArgumentError) { Badger::Fit.new.to_band(hh, band, inset: 25) }
  end

  def test_fit_to_chord_at_y_in_a_rectangle
    setting = Badger::Fit.new.to_chord_at_y(hh, rect_interior, 50, inset: 10)
    min, max = setting.ink_bounds
    assert_in_delta 10, min.x
    assert_in_delta 190, max.x
    assert_in_delta 50, (min.y + max.y) / 2
    assert_in_delta 1.5, setting.size / 100
  end

  def test_baseline_anchor_puts_the_baseline_at_y
    setting = Badger::Fit.new.to_chord_at_y(hh, rect_interior, 80, anchor: :baseline)
    _min, max = setting.ink_bounds
    assert_in_delta 80, max.y
    assert_in_delta 200, setting.ink_bounds.then { |a, b| b.x - a.x }
  end

  def test_chord_fit_inside_a_circle_converges_and_respects_the_narrowest_edge
    interior = Badger::Container.new(Ellipse.circle(100, center: pt(100, 100))).interior
    centered = Badger::Fit.new.to_chord_at_y(hh, interior, 60)
    min, max = centered.ink_bounds
    chord = interior.chord_at_y(60)
    assert_in_delta chord[0], min.x, 0.05
    assert_in_delta chord[1], max.x, 0.05

    fitted = Badger::Fit.new.to_chord_at_y(hh, interior, 60, edge: :narrowest)
    fmin, fmax = fitted.ink_bounds
    assert_operator fmax.x - fmin.x, :<, max.x - min.x
    top_chord = interior.chord_at_y(fmin.y)
    assert_in_delta top_chord[0], fmin.x, 0.05
    assert_in_delta top_chord[1], fmax.x, 0.05

    baseline = Badger::Fit.new.to_chord_at_y(hh, interior, 130, anchor: :baseline, edge: :narrowest)
    bmin, bmax = baseline.ink_bounds
    assert_in_delta 130, bmax.y, 1e-6
    # the ink is tall enough that its top, not its baseline, is the tight edge
    top_chord = interior.chord_at_y(bmin.y)
    bottom_chord = interior.chord_at_y(bmax.y - 1e-9)
    assert_in_delta [top_chord[0], bottom_chord[0]].max, bmin.x, 0.01
    assert_in_delta [top_chord[1], bottom_chord[1]].min, bmax.x, 0.01
  end

  def test_fit_to_chord_at_x
    interior = Badger::Container.new(Ellipse.new(rx: 150, ry: 100, center: pt(150, 100))).interior
    h = font.shape("H", size: 100)
    setting = Badger::Fit.new.to_chord_at_x(h, interior, 150, inset: 10)
    min, max = setting.ink_bounds
    assert_in_delta 10, min.y, 0.05
    assert_in_delta 190, max.y, 0.05
    assert_in_delta 150, (min.x + max.x) / 2
    assert_in_delta 180 / 0.7, setting.size, 0.2 # the chord is a flattened polygon's
  end

  def test_chord_outside_the_region_raises
    assert_raises(Badger::Error) { Badger::Fit.new.to_chord_at_y(hh, rect_interior, 500) }
  end

  def test_fixed_policy_only_positions
    setting = Badger::Fit.new(policy: :fixed).to_chord_at_y(hh, rect_interior, 50)
    assert_equal 100.0, setting.size
    assert_point pt(100, 50), setting.ink_center
  end

  def test_setting_carries_stretch
    result = Badger::Fit.new(axes: :both, stretch: 0.5..2.0).to_box(hh, width: 120, height: 140)
    setting = Badger::Setting.new(result.run, Affine.scale(1, result.stretch))
    assert_in_delta 2.0, setting.stretch
    assert_in_delta 140, setting.ink_bounds.then { |a, b| b.y - a.y }
  end
end
