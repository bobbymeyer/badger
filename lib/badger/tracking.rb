# frozen_string_literal: true

module Badger
  # Tracking on a curve is angular. A tracking value is specified as a length
  # at a set radius; rings at other radii scale it so their letters subtend
  # the same angle and line up radially.
  module Tracking
    def self.at_radius(length, set_radius:, radius:)
      raise ArgumentError, "set_radius must be positive" unless set_radius.positive?

      length * radius / set_radius.to_f
    end

    def self.to_angle(length, radius) = length / radius.to_f
    def self.from_angle(angle, radius) = angle * radius.to_f
  end
end
