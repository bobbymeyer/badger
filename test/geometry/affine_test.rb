# frozen_string_literal: true

require "test_helper"

class AffineTest < Minitest::Test
  include Badger::Geometry

  def test_translate_scale_rotate
    assert_point pt(11, 22), Affine.translate(10, 20).apply(pt(1, 2))
    assert_point pt(2, -6), Affine.scale(2, -3).apply(pt(1, 2))
    assert_point pt(0, 1), Affine.rotate(Math::PI / 2).apply(pt(1, 0))
  end

  def test_composition_applies_the_right_operand_first
    t = Affine.translate(10, 0) * Affine.scale(2)
    assert_point pt(12, 4), t.apply(pt(1, 2))
    u = Affine.scale(2) * Affine.translate(10, 0)
    assert_point pt(22, 4), u.apply(pt(1, 2))
  end

  def test_path_transform_preserves_structure
    path = Path.parse("M 0 0 L 10 0 C 10 5 5 10 0 10 Z")
    moved = path.transform(Affine.translate(5, 5))
    assert_equal "M 5 5 L 15 5 C 15 10 10 15 5 15 Z", moved.to_d
    assert moved.subpaths.first.closed?
  end

  def test_to_svg
    assert_equal "matrix(1 0 0 1 3 4)", Affine.translate(3, 4).to_svg
  end
end
