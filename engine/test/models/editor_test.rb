require "test_helper"

module Badger
  # The inspector is built from the schema; the schema is built from the
  # core's vocabulary. This is the seam where the two would drift apart.
  class EditorTest < ActiveSupport::TestCase
    test "there is a schema for every kind of entry, and a starter that builds" do
      schema = Editor.schema
      assert_equal %w[container child rule band interior follow fit fixed illustration], schema.keys

      starters = Editor.starters(font: FONT)
      starters.each do |kind, entry|
        doc = badge_document
        case kind
        when "rule", "band", "interior" then doc["regions"] << entry
        when "follow" then doc["type"] << entry.merge("region" => "ring")
        when "fit" then doc["type"] << entry.merge("region" => "field")
        when "fixed" then doc["type"] << entry
        when "child" then doc["children"] = [ entry ]
        when "illustration" then doc["illustrations"] = [ entry ]
        end
        assert Badger::Spec.build(doc), "the #{kind} starter does not build"
      end
    end

    test "the schema's choices are the core's" do
      shape = Editor.schema["container"].find { |f| f[:key] == "shape.kind" }
      assert_equal Badger::Spec::SHAPES, shape[:options].map(&:first)
      fit = Editor.schema["fit"].find { |f| f[:key] == "fit" }
      assert_equal Badger::Spec::FITS, fit[:options].map(&:first)
      assert Editor.schema["child"].any? { |f| f[:type] == "locator" }, "a child is placed"
      assert Editor.schema["container"].none? { |f| f[:type] == "locator" }, "the root is not"
    end
  end
end
