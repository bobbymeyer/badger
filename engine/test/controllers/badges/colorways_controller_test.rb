require "test_helper"

module Badger
  class Badges::ColorwaysControllerTest < ActionDispatch::IntegrationTest
    setup { @badge = create_badge }

    test "the picker lists the palettes that can dress the badge, on the ladder" do
      with_pandatone(palettes: { [ 1, "Brand" ] => %w[#111111 #EEEEEE #C1272D], [ 2, "Thin" ] => %w[#000000] }) do
        get new_badge_colorway_path(@badge)

        assert_response :success
        assert_select "header.page-head h1.page-title", text: "Dress Stockholm"
        assert_select "section.palettes", 2, "the palette that cannot dress the badge is demoted, not hidden"
        assert_select "section.palettes:first-of-type tbody tr", 1
        assert_select "section.palettes:first-of-type ol.palette-strip li", 3
        assert_select "section.palettes:last-of-type td", text: "1 short"
        assert_select "form[action=?] button", badge_colorways_path(@badge, palette_id: 1), text: "Dress"
      end
    end

    test "choosing a palette dresses the badge and shows it wearing the colours" do
      with_pandatone(palettes: { [ 1, "Brand" ] => %w[#111111 #EEEEEE] }) do
        assert_difference "Colorway.count", 1 do
          post badge_colorways_path(@badge), params: { palette_id: 1 }
        end
        colorway = Colorway.last
        assert_redirected_to badge_path(@badge, colorway: colorway)
        follow_redirect!
        assert_select "svg path[fill='#111111']"
        assert_select "figcaption", /Wearing Brand/
      end
    end

    test "a slot can be bound to a palette colour from the badge page, and unbound" do
      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#111111", "#EEEEEE", "#C1272D"))
      patch badge_colorway_path(@badge, colorway), params: { rank: 1, kind: "assigned_slot", slot: 2 }
      assert_redirected_to badge_path(@badge, colorway: colorway)
      assert_equal %w[#EEEEEE #C1272D], colorway.reload.colors

      patch badge_colorway_path(@badge, colorway), params: { rank: 1, kind: "auto_value_match" }
      assert_equal %w[#EEEEEE #111111], colorway.reload.colors
    end

    test "drift is asked for and reported" do
      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#111111", "#EEEEEE", id: 1, name: "Brand"))
      with_pandatone(palettes: { [ 1, "Brand" ] => %w[#111111 #FFFFFF] }) do
        patch drift_badge_colorway_path(@badge, colorway)
        assert_redirected_to badge_path(@badge, colorway: colorway)
        assert_match(/has moved in Pandatone/, flash[:notice])
      end
      with_pandatone(palettes: {}) do
        patch drift_badge_colorway_path(@badge, colorway)
        assert_match(/no longer has that palette/, flash[:notice])
      end
    end

    test "Pandatone being unreachable is said, not hidden" do
      with_pandatone(palettes: {}) do
        stub_request(:get, "https://pandatone.test/api/v1/palettes").to_raise(Errno::ECONNREFUSED)

        get new_badge_colorway_path(@badge)

        assert_response :success
        assert_select ".empty", text: /did not answer/
      end
    end

    # No URL means the Pandatone in this process, which the dummy host has
    # and has put nothing in. The picker renders, with nothing to choose.
    test "with no Pandatone url the picker asks the one in this process" do
      Pandatone::Dresser::Catalog.forget!

      get new_badge_colorway_path(@badge)

      assert_response :success
      assert_select "section.palettes .empty", text: "None."
    end

    test "taking a colorway off" do
      colorway = Colorway.create!(badge: @badge, palette: pandatone_palette("#111111", "#EEEEEE"))
      assert_difference "Colorway.count", -1 do
        delete badge_colorway_path(@badge, colorway)
      end
    end
  end
end
