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

    # The document view sends YAML and hears the document back both ways.
    test "a document as YAML renders, and comes back as the document and as YAML" do
      badge = create_badge

      post render_badge_path(badge), params: { document_yaml: "shape: { kind: circle, radius: 90 }\nregions: [ { kind: rule, distance: 0, weight: 4 } ]\n" }, as: :json

      assert_response :success
      body = response.parsed_body
      assert_includes body["svg"], "<path"
      assert_equal 90, body.dig("document", "shape", "radius")
      assert_match(/radius: 90/, body["yaml"])

      post render_badge_path(badge), params: { document_yaml: "shape: [" }, as: :json
      assert_response :unprocessable_content
      assert_match(/not YAML/, response.parsed_body["error"])

      post render_badge_path(badge), params: { document_yaml: "just words" }, as: :json
      assert_response :unprocessable_content
      assert_match(/not a mapping/, response.parsed_body["error"])
    end

    test "a document that does not build is refused with where and why" do
      badge = create_badge

      post render_badge_path(badge), params: { document: { "shape" => { "kind" => "circle" } } }, as: :json

      assert_response :unprocessable_content
      assert_match(/badge\.shape: needs radius/, response.parsed_body["error"])
    end
  end
end
