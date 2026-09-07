require "test_helper"

module Badger
  # The photograph a badge is redrawn from: put on, served, placed, taken off.
  class Badges::ReferencesControllerTest < ActionDispatch::IntegrationTest
    # A one-pixel PNG, enough to be an image with a size.
    PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==").freeze

    def upload
      Rack::Test::UploadedFile.new(StringIO.new(PNG), "image/png", original_filename: "stockholm.png")
    end

    test "a photograph goes under the badge and is served back" do
      badge = create_badge

      post badge_reference_path(badge), params: { reference: { image: upload } }

      assert_redirected_to badge_path(badge)
      reference = badge.reload.reference
      assert_equal [ 1, 1 ], [ reference.width, reference.height ]
      assert_equal "image/png", reference.content_type
      assert_equal 0.5, reference.opacity

      get badge_reference_path(badge)
      assert_response :success
      assert_equal "image/png", response.media_type
      assert_equal PNG, response.body

      get badge_path(badge)
      editor = css_select(".editor").first
      assert_equal 1, JSON.parse(editor["data-badger-editor-reference-value"])["width"]

      get badge_path(badge, section: "export")
      assert_select ".preview-column svg image[data-reference][href=?]", badge_reference_path(badge)
    end

    test "the editor places it and hears back" do
      badge = create_badge
      badge.create_reference!(image: upload)

      patch badge_reference_path(badge), params: { reference: { x: 12, y: -8, scale: 0.5, opacity: 0.3 } }, as: :json

      assert_response :success
      assert_equal({ "x" => 12.0, "y" => -8.0, "scale" => 0.5, "opacity" => 0.3 }, response.parsed_body.slice("x", "y", "scale", "opacity"))
      assert_equal 0.3, badge.reload.reference.opacity

      patch badge_reference_path(badge), params: { reference: { opacity: 4 } }, as: :json
      assert_response :unprocessable_content
    end

    test "taken off, and a badge without one has none to serve" do
      badge = create_badge
      badge.create_reference!(image: upload)

      delete badge_reference_path(badge)

      assert_redirected_to badge_path(badge)
      assert_nil badge.reload.reference
      get badge_reference_path(badge)
      assert_response :not_found
    end

    test "only a PNG or a JPEG is taken" do
      badge = create_badge
      text = Rack::Test::UploadedFile.new(StringIO.new("not an image"), "text/plain", original_filename: "notes.txt")

      post badge_reference_path(badge), params: { reference: { image: text } }

      assert_redirected_to badge_path(badge)
      assert_match(/PNG or a JPEG/, flash[:alert])
      assert_nil badge.reload.reference
    end
  end
end
