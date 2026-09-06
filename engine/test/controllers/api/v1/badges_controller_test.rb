require "test_helper"

module Badger
  class Api::V1::BadgesControllerTest < ActionDispatch::IntegrationTest
    test "the index and a badge by id or name" do
      badge = create_badge
      get api_v1_badges_url
      assert_response :success
      assert_equal [ badge.id ], json.map { |b| b["id"] }

      get api_v1_badge_url("stockholm")
      assert_response :success
      assert_equal "Stockholm", json["name"]
      assert_equal 2, json["slots"]
      assert json["spec"].key?("shape")
      assert_kind_of Hash, json["ink_bounds"]
      assert_match(/\AM /, json["container"])

      get api_v1_badge_url("nothing")
      assert_response :not_found
      assert_equal({ "error" => "Not found" }, json)
    end

    test "the svg is unresolved, and dressed when a colorway is named" do
      badge = create_badge
      colorway = Colorway.create!(badge: badge, palette: pandatone_palette("#111111", "#EEEEEE"))

      get api_v1_badge_url(badge, format: :svg)
      assert_response :success
      assert_equal "image/svg+xml", response.media_type
      assert_match(/var\(--badger-slot-0/, response.body)

      get api_v1_badge_url(badge, format: :svg, colorway: colorway.id, padding: 10)
      assert_includes response.body, 'fill="#111111"'
      assert_no_match(/var\(/, response.body)
    end

    test "colorways" do
      badge = create_badge
      colorway = Colorway.create!(badge: badge, palette: pandatone_palette("#111111", "#EEEEEE"))
      get api_v1_colorways_url
      assert_equal [ colorway.id ], json.map { |c| c["id"] }
      get api_v1_colorway_url(colorway)
      assert_equal %w[#EEEEEE #111111], json["colors"]
      assert_equal 2, json["rules"].size
      get api_v1_colorway_url(colorway, format: :svg)
      assert_includes response.body, 'fill="#EEEEEE"'
    end

    test "the API is behind the host's token, not its session" do
      sign_out_client
      get api_v1_badges_url
      assert_response :unauthorized
      assert_equal({ "error" => "Unauthorized" }, json)
    end
  end
end
