require "test_helper"

module Badger
  # The editor's round trip: a document in, the drawing and its construction
  # out, nothing saved.
  class Badges::RendersControllerTest < ActionDispatch::IntegrationTest
    test "a document renders to the drawing, its construction and its warnings without being saved" do
      badge = create_badge
      document = badge.spec.deep_dup
      document["shape"]["rx"] = 300

      post render_badge_path(badge), params: { document: document }, as: :json

      assert_response :success
      body = response.parsed_body
      assert_includes body["svg"], 'data-address="type[0]"'
      assert_equal "container", body["construction"].first["kind"]
      assert_equal 12.0, body["padding"]
      assert_equal %w[ground ink], body["slots"].map { |s| s["name"] }
      assert_operator body["ink"]["width"], :>, 500, "the wider ellipse was drawn"
      assert_equal 260, badge.reload.spec["shape"]["rx"], "nothing was saved"
    end

    test "a document that does not build is refused with where and why" do
      badge = create_badge

      post render_badge_path(badge), params: { document: { "shape" => { "kind" => "circle" } } }, as: :json

      assert_response :unprocessable_content
      assert_match(/badge\.shape: needs radius/, response.parsed_body["error"])
    end
  end
end
