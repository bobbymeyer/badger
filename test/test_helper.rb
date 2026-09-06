# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "badger"
require "minitest/autorun"

module GeometryAssertions
  P = Badger::Geometry::Point

  def assert_point(expected, actual, delta = 1e-6)
    assert_in_delta expected.x, actual.x, delta, "x of #{actual} vs #{expected}"
    assert_in_delta expected.y, actual.y, delta, "y of #{actual} vs #{expected}"
  end

  def pt(x, y) = P.new(x.to_f, y.to_f)
end

Minitest::Test.include GeometryAssertions
