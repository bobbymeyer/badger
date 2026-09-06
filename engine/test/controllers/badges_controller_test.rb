require "test_helper"

module Badger
  class BadgesControllerTest < ActionDispatch::IntegrationTest
    test "the index draws every badge in value" do
      create_badge(name: "Stockholm")
      create_badge(name: "Kiruna")

      get badges_path

      assert_response :success
      assert_select "ul.badge-cards li", 2
      assert_select "svg", 2
      assert_select "link[rel=stylesheet][href*='badger/components']"
    end

    test "an empty index says so" do
      get badges_path
      assert_select ".empty"
    end

    test "showing a badge draws it and lists its slots" do
      badge = create_badge

      get badge_path(badge)

      assert_response :success
      assert_select "svg path[data-slot]", minimum: 3
      assert_select "table.slots tbody tr", 2
      assert_select "details.document code", /kind: ellipse/
    end

    test "composing a badge from the editor, and refusing a document that does not build" do
      get new_badge_path
      assert_select "textarea[name='badge[spec_yaml]']", /shape:/

      assert_difference "Badge.count", 1 do
        post badges_path, params: { badge: { name: "Kiruna", spec_yaml: "shape: { kind: circle, radius: 80 }\nregions: [ { kind: rule, distance: 0, weight: 4 } ]\n" } }
      end
      assert_redirected_to badge_path(Badge.last)

      assert_no_difference "Badge.count" do
        post badges_path, params: { badge: { name: "Broken", spec_yaml: "shape: { kind: circle }\n" } }
      end
      assert_response :unprocessable_content
      assert_select ".errors", /badge\.shape: needs radius/
    end

    test "editing, saving and deleting" do
      badge = create_badge
      get edit_badge_path(badge)
      assert_response :success

      patch badge_path(badge), params: { badge: { name: "Stockholm Stadion" } }
      assert_redirected_to badge_path(badge)
      assert_equal "Stockholm Stadion", badge.reload.name

      assert_difference "Badge.count", -1 do
        delete badge_path(badge)
      end
      assert_redirected_to badges_path
    end

    test "the screens are behind the host's door" do
      sign_out
      get badges_path
      assert_response :unauthorized
    end
  end
end
