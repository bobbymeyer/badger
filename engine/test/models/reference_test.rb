require "test_helper"

module Badger
  class ReferenceTest < ActiveSupport::TestCase
    test "a JPEG's size is read from its frame header" do
      # SOI, an APP0 segment, then a baseline frame of 640 × 480
      jpeg = "\xFF\xD8".b + "\xFF\xE0\x00\x04\x00\x00".b + "\xFF\xC0\x00\x11\x08".b + [ 480, 640 ].pack("nn") + "\x03".b
      assert_equal [ 640, 480 ], Reference.measure(jpeg)
    end

    test "the box is centred on the placement, at the scale, in badge units" do
      reference = Reference.new(width: 800, height: 600, x: 10, y: -20, scale: 0.5)
      assert_equal({ x: -190.0, y: -170.0, width: 400.0, height: 300.0 }, reference.box)
    end
  end
end
