# frozen_string_literal: true

module Badger
  # Regions derived from a single container. Three kinds, no others:
  # Offset (a rule), Band (an annulus, where following type sits) and
  # Interior (what is left inside the innermost offset). Visibility is
  # per region.
  module Regions
    class Base
      attr_reader :container, :name, :slot, :address

      # address: where in a document this region was written, for an editor
      # that has to find its way back from a piece to the entry that made it.
      def initialize(container, visible:, name:, slot: :ink, address: nil)
        @container = container
        @visible = visible
        @name = name
        @slot = Slot.rank(slot)
        @address = address
      end

      def visible? = @visible
      def tolerance = container.tolerance

      # Bounds of the region's fill path.
      def bounds = path.bounds(tolerance: tolerance)

      private

      # A ring between two spines, inner reversed so the fill is correct
      # under both nonzero and evenodd rules.
      def annulus(outer, inner)
        outer.to_path(tolerance: tolerance) + inner.reversed.to_path(tolerance: tolerance)
      end
    end
  end
end

require_relative "regions/offset"
require_relative "regions/band"
require_relative "regions/interior"
