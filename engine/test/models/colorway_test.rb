require "test_helper"

module Badger
  class ColorwayTest < ActiveSupport::TestCase
    setup { @badge = create_badge }

    test "choosing a palette takes a snapshot, and the colours resolve by rank" do
      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#12120F", "#FAF8F4", "#C1272D"))
      assert_equal "Sample", colorway.palette_name
      assert_equal 3, colorway.snapshot.size
      # two slots: the lightest is the ground, the darkest is ink
      assert_equal %w[#FAF8F4 #12120F], colorway.colors
      assert_equal({ 0 => "#FAF8F4", 1 => "#12120F" }, colorway.fills)
      assert_includes colorway.svg, 'fill="#12120F"'
    end

    test "a slot can be bound to a palette index, and unbound again" do
      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#12120F", "#FAF8F4", "#C1272D"))
      colorway.bind(1, kind: "assigned_slot", index: 2)
      assert_equal %w[#FAF8F4 #C1272D], colorway.colors
      assert_raises(ActiveRecord::RecordInvalid) { colorway.bind(1, kind: "assigned_slot", index: 9) }
      colorway.rules.destroy_all
      assert_equal %w[#FAF8F4 #12120F], colorway.reload.colors
    end

    test "a palette with fewer colours than slots is refused, and drift is reported not applied" do
      colorway = Colorway.new(badge: @badge, palette: pandatone_palette("#12120F"))
      assert_not colorway.valid?
      assert_match(/1 colours and the badge has 2 slots/, colorway.errors[:palette].first)

      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#12120F", "#FAF8F4"))
      assert_not colorway.snapshot.drifted_from?(pandatone_palette("#12120F", "#FAF8F4"))
      assert colorway.snapshot.drifted_from?(pandatone_palette("#12120F", "#FFFFFF"))
      assert_equal %w[#FAF8F4 #12120F], colorway.colors, "the snapshot still dresses the badge"
    end

    test "a badge that outgrows its palette invalidates the colorway without losing it" do
      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#12120F", "#FAF8F4"))
      spec = @badge.spec.merge("regions" => @badge.spec["regions"].map { |r| r["kind"] == "band" ? r.merge("visible" => true) : r })
      @badge.update!(spec: spec)
      assert_equal 3, @badge.reload.slot_count
      assert colorway.reload.invalidated?
      assert_equal [], colorway.colors
    end

    test "luminance ranks a palette paper first" do
      palette = pandatone_palette("#12120F", "#C1272D", "#FAF8F4")
      assert_equal %w[#FAF8F4 #C1272D #12120F], palette.ranked.map(&:hex)
      assert_in_delta 1.0, Luminance.of(255, 255, 255), 1e-6
      assert_in_delta 0.0, Luminance.of(0, 0, 0), 1e-6
    end

    test "the catalogue reads Pandatone's wire format through the configured source" do
      with_pandatone(palettes: { [ 1, "Brand" ] => %w[#111111 #EEEEEE #C1272D], [ 2, "Thin" ] => %w[#000000] }) do
        catalog = Pandatone::Catalog.current
        assert_equal %w[Brand Thin], catalog.palettes.map(&:name)
        assert_equal %w[Brand], catalog.serving(2).map(&:name)
        assert_equal 3, catalog.palettes.first.size
      end
    end

    test "an unreachable or refusing Pandatone is its own error, not an empty catalogue" do
      stub_request(:get, "https://pandatone.test/api/v1/palettes").to_return(status: 401)
      Badger.pandatone_url = "https://pandatone.test"
      Badger.pandatone_token = "x"
      assert_raises(Pandatone::Unauthorized) { Pandatone::Client.configured.palettes_json }
    ensure
      Badger.pandatone_url = Badger.pandatone_token = nil
    end
  end
end
