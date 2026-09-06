# frozen_string_literal: true

module Badger
  # The whole effects budget: knockout, a single offset stroke, and the
  # union that must precede either. Anything beyond this belongs to a
  # register Badger is not aiming at.
  module Effects
    module_function

    # Type or artwork subtracted from a filled region.
    def knockout(fill, *cut) = Booleans.difference(fill, *cut)

    # A single outward offset of the union of `paths`, as a ring that can
    # be filled behind or around them.
    def offset_stroke(paths, distance, join: :round)
      raise ArgumentError, "an offset stroke needs a positive distance" unless distance.positive?

      Booleans.difference(Booleans.expand(paths, distance, join: join), Booleans.union(paths))
    end

    # The union grown by `distance`: the patch behind a block of type.
    def plate(paths, distance, join: :round) = Booleans.expand(paths, distance, join: join)
  end
end
