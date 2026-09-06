module Badger
  module ApplicationHelper
    # A badge, drawn. Undressed it renders in value, paper to ink, which is
    # not a placeholder: a badge is composed in value and is complete without
    # a palette. Handed a colorway, it wears it.
    def badge_preview(badge, colorway: nil, padding: 12, **options)
      svg = colorway ? colorway.svg(padding: padding) : badge.svg(padding: padding)
      tag.div(svg.html_safe, **options, class: token_list("preview", options[:class]))
    rescue Badger::Error => e
      tag.p("Cannot draw: #{e.message}", class: "preview preview--failed")
    end

    def slot_swatch(hex)
      tag.span(class: "slot-swatch", style: "background: #{hex}")
    end

    # A palette as the picker shows it: its colours in lightness rank, drawn
    # as the greys of their own lightness. Choose on the ladder, then look at
    # the preview.
    def palette_strip(palette)
      tag.ol(class: "palette-strip") do
        safe_join(palette.ranked.map do |color|
          tag.li do
            safe_join([
              tag.span(class: "palette-swatch", style: "background: #{Badger::Value.grey(color.luminance)}"),
              tag.span(color.name, class: "palette-swatch__name")
            ])
          end
        end)
      end
    end

    def rule_name(rule)
      rule.assigned_slot? ? "Palette colour #{rule.index}" : "By rank"
    end
  end
end
