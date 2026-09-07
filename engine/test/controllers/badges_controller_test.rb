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

    # The compose surface is the editor: the document, its render and the
    # inspector's schema handed to it on the page, so it draws before it asks
    # the server for anything.
    test "showing a badge opens the editor with the document and its render" do
      badge = create_badge

      get badge_path(badge)

      assert_response :success
      editor = css_select(".editor[data-controller='badger-editor']").first
      assert editor, "the compose surface is the editor"
      assert_equal "ellipse", JSON.parse(editor["data-badger-editor-document-value"]).dig("shape", "kind")
      rendering = JSON.parse(editor["data-badger-editor-rendering-value"])
      assert_includes rendering["svg"], 'data-address="type[0]"'
      assert_equal %w[container rule band interior follow type], rendering["construction"].map { |c| c["kind"] }
      assert JSON.parse(editor["data-badger-editor-schema-value"]).key?("follow")
      assert_select "button[form='badger-editor-save']", text: "Save"
      assert_select "form#badger-editor-save[action=?]", badge_path(badge)
      assert_select "ol.tree"
      assert_select "svg.stage"
      assert_select "template[data-badger-editor-target=templates] [data-field=number]"
    end

    test "the export surface lists the slots the files carry, and the document" do
      badge = create_badge

      get badge_path(badge, section: "export")

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
      assert_select ".editor", 0
      assert_select ".preview-column svg path[data-slot]", minimum: 3, message: "the drawing stays on every surface"
    end

    # The start: a composition on a shape, each composition drawn by the
    # core, or a document pasted whole. Composed, the badge opens in the
    # editor on its first run.
    test "the start offers the compositions and the shapes" do
      get new_badge_path

      assert_response :success
      assert_select "form.start[data-controller='badger-start']"
      assert_select ".compositions .composition input[type=radio][name='badge[composition]']", Badger::Compositions.all.size
      assert_select ".composition input[value=ring][checked]"
      assert_select ".composition .figure > svg", Badger::Compositions.all.size, "every composition is drawn"
      assert_select ".shapes .shape input[type=radio][name='badge[shape]']", Badger::Compositions::SHAPES.size
      assert_select ".shape input[value=superellipse][checked]"
      assert_select ".shape svg.shape__glyph path", Badger::Compositions::SHAPES.size
      assert_select "button[type=submit]", text: "Compose a ring on a superellipse"
      assert_select "details.start__paste summary", text: "Or paste a document"
      assert_select "textarea[name='badge[spec_yaml]']"
    end

    test "composing from a composition on a shape opens the editor on the first run" do
      assert_difference "Badge.count", 1 do
        post badges_path, params: { badge: { name: "", composition: "stack", shape: "circle" } }
      end
      badge = Badge.last
      assert_redirected_to badge_path(badge, select: "type[0]")
      assert_equal "Lozenge stack", badge.name
      assert_equal "circle", badge.spec.dig("shape", "kind")
      assert_equal "chord_at_y", badge.spec.dig("type", 0, "fit")

      follow_redirect!
      assert_select ".editor[data-badger-editor-select-value='type[0]']"
    end

    test "composing from a pasted document, and refusing one that does not build" do
      assert_difference "Badge.count", 1 do
        post badges_path, params: { badge: { name: "Kiruna", composition: "ring", shape: "circle",
          spec_yaml: "shape: { kind: circle, radius: 80 }\nregions: [ { kind: rule, distance: 0, weight: 4 } ]\n" } }
      end
      assert_equal "circle", Badge.last.spec.dig("shape", "kind")
      assert_equal 80, Badge.last.spec.dig("shape", "radius"), "the pasted document is taken over the composition"

      assert_no_difference "Badge.count" do
        post badges_path, params: { badge: { name: "Broken", spec_yaml: "shape: { kind: circle }\n" } }
      end
      assert_response :unprocessable_content
      assert_select ".errors", /badge\.shape: needs radius/
      assert_select ".composition input[value=ring][checked]", 1, "the start is shown again, with its choices"
    end

    test "a path shape needs its path data" do
      assert_no_difference "Badge.count" do
        post badges_path, params: { badge: { name: "Traced", composition: "plate", shape: "path", path: "" } }
      end
      assert_response :unprocessable_content
      assert_select ".errors", /path data/

      post badges_path, params: { badge: { name: "Traced", composition: "plate", shape: "path", path: "M -280 -160 L 280 -160 L 280 160 L -280 160 Z" } }
      assert_redirected_to badge_path(Badge.last, select: "type[0]")
      assert_equal "path", Badge.last.spec.dig("shape", "kind")
    end

    # The document is the editor's second view: the same badge as YAML,
    # handed to the page with the drawing.
    test "the editor carries the document as YAML for its document view" do
      badge = create_badge

      get badge_path(badge)

      assert_select ".editor__views .editor__view[data-view=drawing][aria-current]"
      assert_select ".editor__views .editor__view[data-view=document]"
      assert_select "textarea#badger-editor-yaml[data-badger-editor-target=yaml][data-controller='badger-document']"
      editor = css_select(".editor").first
      assert_match(/kind: ellipse/, editor["data-badger-editor-yaml-value"])
    end

    # The editor saves the document whole, as JSON, and hears back.
    test "the editor saves the document as JSON" do
      badge = create_badge
      document = badge.spec.deep_dup
      document["shape"]["rx"] = 300

      patch badge_path(badge), params: { badge: { spec: document } }, as: :json

      assert_response :success
      assert response.parsed_body["saved_at"]
      assert_equal 300, badge.reload.spec["shape"]["rx"]

      patch badge_path(badge), params: { badge: { spec: { "shape" => { "kind" => "circle" } } } }, as: :json
      assert_response :unprocessable_content
      assert_match(/needs radius/, response.parsed_body["error"])
      assert_equal 300, badge.reload.spec["shape"]["rx"]
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
