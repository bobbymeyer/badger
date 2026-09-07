# frozen_string_literal: true

require "test_helper"

# The three reference badges, built with the fixture font. What is asserted
# is the geometry the handoff names for each; whether the result matches the
# reference image is the half only an eye can judge: see
# examples/acceptance.rb and the images beside these tests.
module AcceptanceHelper
  FIXTURES = File.expand_path("../fixtures", __dir__)

  def setup
    Badger::Fonts.reset!.add_directory(FIXTURES)
  end

  def teardown = Badger::Fonts.reset!

  def build(name)
    doc = Badger::References.public_send(name, font: "badger-test")
    container = Badger::Spec.build(doc)
    [container, Badger.render(container)]
  end

  def node(container, name) = container.nodes.find { |n| n.name == name } or flunk("no node named #{name}")

  # Whether a point lies inside an interior region, by its horizontal spans.
  def within?(interior, point)
    interior.spans_at_y(point.y).any? { |a, b| a - 1e-6 <= point.x && point.x <= b + 1e-6 }
  end

  def ink_points(path, tolerance = 0.5) = path.spines.flat_map { |s| s.flatten(tolerance) }

  def degrees(point) = (Math.atan2(point.y, point.x) * 180 / Math::PI) % 360
end
