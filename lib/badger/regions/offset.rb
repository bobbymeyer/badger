# frozen_string_literal: true

module Badger
  module Regions
    # The container path offset by `distance` (positive outward), rendered
    # as a rule `weight` thick centred on that offset.
    class Offset < Base
      attr_reader :distance, :weight

      def initialize(container, distance:, weight:, visible:, name:, slot: :ink, address: nil)
        raise ArgumentError, "weight must be positive" unless weight.positive?

        super(container, visible: visible, name: name, slot: slot, address: address)
        @distance = distance.to_f
        @weight = weight.to_f
      end

      # The centreline of the rule; also a spine type can follow.
      def spine = container.offset(distance)

      def outer_edge = container.offset(distance + weight / 2)
      def inner_edge = container.offset(distance - weight / 2)

      # Fill geometry of the rule.
      def path = annulus(outer_edge, inner_edge)
    end
  end
end
