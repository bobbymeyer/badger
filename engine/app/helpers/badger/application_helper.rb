module Badger
  module ApplicationHelper
    # A badge, drawn. Undressed it renders in value, paper to ink, which is
    # not a placeholder: a badge is composed in value and is complete without
    # a palette. Handed a colorway, it wears it. The swatches, the strips and
    # the rule in words are Pandatone's dresser's.
    #
    # bare: the SVG on its own, for a .figure that sizes its own picture.
    # reference: a Reference drawn under the badge at its own strength, the
    # photograph the badge is redrawn from.
    def badge_preview(badge, colorway: nil, padding: 12, bare: false, reference: nil, **options)
      svg = colorway ? colorway.svg(padding: padding) : badge.svg(padding: padding)
      svg = with_reference(svg, badge, reference) if reference
      svg = svg.html_safe # rubocop:disable Rails/OutputSafety -- the core's own SVG
      return svg if bare

      tag.div(svg, **options, class: token_list("preview", options[:class]))
    rescue Badger::Error => e
      tag.p("Cannot draw: #{e.message}", class: "preview preview--failed")
    end

    # A composition, drawn: the core's own render of the document choosing
    # it gives, in value, so the card never drifts from the badge. Rendered
    # once per font and version and kept in the host's cache; the sidecar
    # is not asked six times for every visit to the start.
    def composition_preview(composition, font:)
      svg = Rails.cache.fetch([ "badger", Badger::VERSION, "composition", composition.key, font ]) do
        Badge.new(name: composition.name, spec: Compositions.document(composition.key, font: font)).svg(padding: 12)
      end
      svg.html_safe # rubocop:disable Rails/OutputSafety -- the core's own SVG
    rescue Badger::Error => e
      tag.p("Cannot draw: #{e.message}", class: "empty")
    end

    # A shape's outline at a glyph's size, from the core's own path, so the
    # row of shapes is the shapes the core draws and not a picture of them.
    def shape_glyph(kind)
      frame = [ 56, 44 ]
      d = if kind == "path"
        "M 4 30 C 12 4, 22 4, 28 20 S 44 40, 52 12"
      else
        Badger::Spec.build({ "shape" => Compositions.shape_for(kind, frame) }).path.to_d
      end
      tag.svg(tag.path(d: d), viewBox: "-30 -24 60 48", class: "shape__glyph", "aria-hidden": true)
    end

    # The reference under the pieces: an image in the badge's own units,
    # first in the SVG so everything drawn is over it, clipped to the
    # drawing's own box the way the editor shows it.
    def with_reference(svg, badge, reference)
      box = reference.box
      image = tag.image(href: badge_reference_path(badge), x: box[:x], y: box[:y], width: box[:width], height: box[:height],
                        opacity: reference.opacity, preserveAspectRatio: "none", "data-reference": true)
      svg.sub(/(<svg\b[^>]*>)/) { "#{Regexp.last_match(1)}\n  #{image}" }
    end
  end
end
