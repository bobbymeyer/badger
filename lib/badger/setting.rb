# frozen_string_literal: true

module Badger
  # A run placed in badge space: the run plus the affine that puts it there.
  # The affine may carry a non-uniform stretch; the run itself is always
  # uniformly scaled.
  class Setting
    attr_reader :run, :affine

    def initialize(run, affine = Geometry::Affine.identity)
      @run = run
      @affine = affine
    end

    def path = run.path.transform(affine)
    def ink_bounds(tolerance: 0.1) = path.bounds(tolerance: tolerance)

    def ink_center
      min, max = ink_bounds
      (min + max) / 2
    end

    def stretch = affine.d / affine.a
    def size = run.size
    def with_affine(new_affine) = Setting.new(run, new_affine)
    def transform(by) = Setting.new(run, by * affine)
  end
end
