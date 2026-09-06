# frozen_string_literal: true

require "test_helper"

# Uses test/fixtures/badger-test.ttf (build_test_font.py): upem 1000,
# cap height 700, x height 500, A/V/H/O advance 600, T 500, I 300, f 300,
# i 250, f_i 500, space 250; kern A V -100, T A -80; liga f i -> f_i.
class FontTest < Minitest::Test
  FIXTURE = File.expand_path("fixtures/badger-test.ttf", __dir__)

  def font = (@font ||= Badger::Font.new(FIXTURE))

  def test_advances_are_scaled_to_size_with_kerning_applied
    run = font.shape("AV", size: 100)
    assert_equal [50.0, 60.0], run.advances
    assert_equal 110.0, run.width
    assert_equal %w[A V], run.glyphs.map(&:name)
    assert_equal "AV", run.text
  end

  def test_metrics_scale
    run = font.shape("H", size: 50)
    assert_equal 35.0, run.cap_height
    assert_equal 25.0, run.x_height
    assert_equal 40.0, run.metrics.ascender
    assert_equal(-10.0, run.metrics.descender)
  end

  def test_ligature_fires_and_can_be_switched_off
    assert_equal %w[f_i], font.shape("fi", size: 100).glyphs.map(&:name)
    assert_equal %w[f i], font.shape("fi", size: 100, features: { liga: false }).glyphs.map(&:name)
    assert_equal "fi", font.shape("fi", size: 100).glyphs.first.text
  end

  def test_kerning_can_be_switched_off
    assert_equal [60.0, 60.0], font.shape("AV", size: 100, features: { kern: false }).advances
  end

  def test_pair_overrides_add_to_the_fonts_kerning
    run = font.shape("TAV", size: 100, pair_overrides: { "AV" => -20, "TA" => 5 })
    assert_equal [47.0, 30.0, 60.0], run.advances
  end

  def test_outlines_are_in_badge_units_with_y_down_and_pen_at_origin
    run = font.shape("I", size: 100)
    glyph = run.glyphs.first
    assert glyph.ink?
    min, max = glyph.path.bounds
    assert_point pt(10, -70), min
    assert_point pt(20, 0), max
  end

  def test_space_has_no_ink
    run = font.shape("A A", size: 100)
    refute run.glyphs[1].ink?
    assert_equal 3, run.glyphs.size
    assert_equal 2, run.path.subpaths.size
  end

  def test_run_path_lays_glyphs_out_by_pen_position
    run = font.shape("IH", size: 100)
    assert_equal [0.0, 30.0], run.pen_positions
    min, max = run.ink_bounds
    assert_point pt(10, -70), min
    assert_point pt(90, 0), max
  end

  def test_ink_bounds_of_an_all_space_run_is_nil
    assert_nil font.shape(" ", size: 100).ink_bounds
  end

  def test_missing_font_file
    assert_raises(ArgumentError) { Badger::Font.new("/nowhere/nothing.ttf") }
  end

  def test_sidecar_errors_surface_as_ruby_errors
    error = assert_raises(Badger::Sidecar::Error) { Badger.sidecar.call({ op: "nonsense" }) }
    assert_match(/unknown op/, error.message)
  end

  def test_missing_interpreter_is_reported_not_crashed
    sidecar = Badger::Sidecar.new(python: "/nowhere/python-that-does-not-exist")
    assert_raises(Badger::Sidecar::Unavailable) { sidecar.call({ op: "doctor" }) }
    report = sidecar.doctor
    refute report["ok"]
    assert_equal %w[fonttools uharfbuzz], report["missing"]
  end

  def test_doctor_reports_ok_here
    report = Badger.doctor
    assert report["ok"], report.inspect
    assert report["fonttools"]
    assert report["uharfbuzz"]
  end

  def test_shapes_a_real_system_font_when_present
    path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    skip "DejaVu Sans not installed" unless File.file?(path)

    run = Badger::Font.new(path).shape("Stockholm", size: 48)
    assert_equal 9, run.glyphs.size
    assert run.glyphs.all?(&:ink?)
    assert_operator run.width, :>, 150
    assert_operator run.cap_height, :>, 30
  end
end
