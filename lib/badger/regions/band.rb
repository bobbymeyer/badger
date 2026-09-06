# frozen_string_literal: true

module Badger
  module Regions
    # The annulus between two offsets of the container. Following type sits
    # here: the baseline is a spine somewhere inside the band, chosen with
    # `spine_at`.
    class Band < Base
      attr_reader :outer, :inner

      def initialize(container, outer:, inner:, visible:, name:, slot: :ink)
        raise ArgumentError, "a band's outer distance must exceed its inner distance" unless outer > inner

        super(container, visible: visible, name: name, slot: slot)
        @outer = outer.to_f
        @inner = inner.to_f
      end

      def width = outer - inner
      def outer_edge = container.offset(outer)
      def inner_edge = container.offset(inner)

      # A spine inside the band: 0.0 is the inner edge, 1.0 the outer edge.
      def spine_at(fraction)
        raise ArgumentError, "fraction must be within 0..1" unless (0.0..1.0).cover?(fraction)

        container.offset(inner + width * fraction)
      end

      # A spine `inset` inside the band from the named edge. Type reading
      # around the top sits on a baseline inset from the inner edge; type
      # reversed along the bottom sits inset from the outer edge.
      def baseline(inset, from: :inner)
        raise ArgumentError, "inset must be within the band" unless (0.0..width).cover?(inset)

        case from
        when :inner then container.offset(inner + inset)
        when :outer then container.offset(outer - inset)
        else raise ArgumentError, "from: must be :inner or :outer"
        end
      end

      def middle = spine_at(0.5)

      # Fill geometry of the annulus.
      def path = annulus(outer_edge, inner_edge)
    end
  end
end
