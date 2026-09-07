require "test_helper"

module Badger
  class BadgesControllerTest < ActionDispatch::IntegrationTest
    test "the index draws every badge in value" do
      create_badge(name: "Stockholm")
      create_badge(name: "Kiruna")

      get badges_path

      assert_response :success
      assert_select "header.page-head h1.page-title", text: "Badges"
      assert_select "ul.cards > li.badge-card", 2
      assert_select ".badge-card .card__figure > svg", 2
      assert_select "link[rel=stylesheet][href*='badger/components']"
      assert_select "link[rel=stylesheet][href*='pandatone/dresser']"
      assert_select "script[type=module]", /import "badger"/
    end

    # The library's filter block: a search that narrows as you type, into the
    # frame the cards are in, and a register for what the badge is wearing.
    test "the index narrows by name and by what is worn, and keeps its order" do
      dressed = create_badge(name: "Stockholm")
      create_badge(name: "Kiruna")
      Colorway.create!(badge: dressed, palette: pandatone_palette("#111111", "#EEEEEE"))

      get badges_path(q: "o", wearing: "dressed", sort: "newest")

      assert_select ".filters form[data-controller='its-swiss-live-search'][data-turbo-frame=badges]"
      assert_select "[data-filter=wearing] a[aria-current]", text: "Dressed"
      assert_select "[data-filter=sort] a[aria-current]", text: "Newest"
      assert_select "turbo-frame#badges .badge-card", 1
      assert_select ".badge-card .card__name", text: "Stockholm"

      get badges_path(q: "zzz")
      assert_select ".empty", text: "No badges match."
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

    # The page's three surfaces, named under the title; the one shown in the
    # weight, and shown alone. The drawing is on every one.
    test "the badge page is three surfaces, reached from the head" do
      badge = create_badge

      get badge_path(badge)
      assert_equal %w[ Compose Dress Export ], css_select("header.page-head nav.sections a").map(&:text)
      assert_select "nav.sections a[aria-current=page]", text: "Compose"
      assert_select "section.export", 0

      get badge_path(badge, section: "export")
      assert_select "nav.sections a[aria-current=page]", text: "Export"
      assert_select "section.export a[href=?]", api_v1_badge_path(badge, format: :svg)
      assert_select "table.slots", 0
      assert_select ".preview-column svg path[data-slot]", minimum: 3, message: "the drawing stays on every surface"
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
