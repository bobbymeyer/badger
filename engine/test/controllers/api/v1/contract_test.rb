require "test_helper"

# The whole of v1, snapshotted: keys, their order and their types. Treat a
# failure here as a version bump rather than a fix.
module Badger
  class Api::V1::ContractTest < ActionDispatch::IntegrationTest
    setup do
      @badge = create_badge
      @colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#C1272D", "#FAF8F4", "#12120F"))
      @colorway.bind(1, kind: "assigned_slot", index: 0)
    end

    test "the badges index returns exactly this shape" do
      get api_v1_badges_url
      assert_equal [ { "id" => @badge.id, "name" => "Stockholm", "slots" => 2, "colorways" => 1 } ], json
    end

    test "a badge returns exactly these keys, in this order" do
      get api_v1_badge_url(@badge)
      assert_equal %w[id name slots colorways spec ink_bounds optical_center anchors container slot_list pieces], json.keys
      assert_equal %w[x y width height], json["ink_bounds"].keys
      assert_equal %w[top_left top top_right left center right bottom_left bottom bottom_right centroid], json["anchors"].keys
      assert_equal [ { "rank" => 0, "name" => "ground", "property" => "--badger-slot-0", "value" => json["slot_list"][0]["value"] },
                     { "rank" => 1, "name" => "ink", "property" => "--badger-slot-1", "value" => json["slot_list"][1]["value"] } ], json["slot_list"]
      assert_equal %w[kind name slot depth], json["pieces"].first.keys
    end

    test "a colorway returns exactly this shape" do
      get api_v1_colorway_url(@colorway)
      assert_equal({
        "id" => @colorway.id, "badge_id" => @badge.id, "palette_id" => 7, "palette_name" => "Sample", "invalidated" => false,
        "taken_at" => @colorway.snapshot.taken_at.iso8601,
        "rules" => [ { "slot" => 0, "kind" => "auto_value_match", "settings" => {} },
                     { "slot" => 1, "kind" => "assigned_slot", "settings" => { "index" => 0 } } ],
        "colors" => [ "#FAF8F4", "#C1272D" ]
      }, json)
    end

    test "the errors are enveloped" do
      get api_v1_badge_url("nowhere")
      assert_equal({ "error" => "Not found" }, json)
      sign_out_client
      get api_v1_badges_url
      assert_equal({ "error" => "Unauthorized" }, json)
    end
  end
end
