require "test_helper"

module Badger
  class BadgeTest < ActiveSupport::TestCase
    test "a badge is its document, and renders from it" do
      badge = create_badge
      assert_equal 2, badge.slot_count
      assert_match(/var\(--badger-slot-0/, badge.svg)
      assert_includes badge.svg(colors: { 0 => "#fff" }), 'fill="#fff"'
      assert_equal %w[ground ink], badge.slots.map(&:name)
    end

    test "names are required, stripped and unique regardless of case" do
      create_badge(name: "Stockholm")
      assert_not Badge.new(name: " stockholm ", spec: badge_document).valid?
      assert_not Badge.new(name: "", spec: badge_document).valid?
      assert_equal "Kiruna", Badge.create!(name: " Kiruna ", spec: badge_document(name: "Kiruna")).name
    end

    test "the document is validated by building it, and the error says where" do
      badge = Badge.new(name: "Broken", spec: { "shape" => { "kind" => "circle" } })
      assert_not badge.valid?
      assert_match(/badge\.shape: needs radius/, badge.errors[:spec].first)

      badge = Badge.new(name: "Empty", spec: {})
      assert_not badge.valid?
      assert_equal [ "is empty" ], badge.errors[:spec]
    end

    test "the document is edited as YAML, and YAML that does not parse is refused with its reason" do
      badge = create_badge
      assert_match(/kind: ellipse/, badge.spec_yaml)

      badge.spec_yaml = "shape: { kind: circle, radius: 40 }\nregions: [ { kind: rule, distance: 0 } ]\n"
      assert badge.valid?
      assert_equal "circle", badge.spec["shape"]["kind"]

      badge.spec_yaml = "shape: {{{"
      assert_not badge.valid?
      assert_match(/is not YAML/, badge.errors[:spec].first)
      assert_equal "shape: {{{", badge.spec_yaml, "what was typed stays in the editor"
    end

    test "friendly finds by id or name" do
      badge = create_badge(name: "Stockholm")
      assert_equal badge, Badge.friendly(badge.id)
      assert_equal badge, Badge.friendly("stockholm")
      assert_nil Badge.friendly("Nothing")
      assert_nil Badge.friendly("")
    end

    test "the seeds plant a small library once" do
      Seeds.plant(font: FONT)
      count = Badge.count
      assert_operator count, :>=, 3
      Seeds.plant(font: FONT)
      assert_equal count, Badge.count
      assert Badge.friendly("Stockholm Stadion").svg.include?("<path")
    end

    test "the starter document composes" do
      badge = Badge.new(name: "Starter", spec: Seeds.starter(font: FONT))
      assert badge.valid?, badge.errors.full_messages.to_sentence
    end
  end
end
