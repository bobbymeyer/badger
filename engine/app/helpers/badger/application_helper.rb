module Badger
  module ApplicationHelper
    # A badge, drawn. Undressed it renders in value, paper to ink, which is
    # not a placeholder: a badge is composed in value and is complete without
    # a palette. Handed a colorway, it wears it. The swatches, the strips and
    # the rule in words are Pandatone's dresser's.
    #
    # bare: the SVG on its own, for a .figure that sizes its own picture.
    def badge_preview(badge, colorway: nil, padding: 12, bare: false, **options)
      svg = (colorway ? colorway.svg(padding: padding) : badge.svg(padding: padding)).html_safe # rubocop:disable Rails/OutputSafety -- the core's own SVG
      return svg if bare

      tag.div(svg, **options, class: token_list("preview", options[:class]))
    rescue Badger::Error => e
      tag.p("Cannot draw: #{e.message}", class: "preview preview--failed")
    end
  end
end
