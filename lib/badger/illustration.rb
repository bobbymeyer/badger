# frozen_string_literal: true

require "rexml/document"

module Badger
  # Imported artwork. Two rules from the handoff:
  #
  # - measure ink bounds, not the viewBox; imported SVGs carry arbitrary
  #   padding, so placement and fitting use the geometry alone
  # - strip baked fills and take one colour slot; artwork with more than one
  #   fill passes through as-is, keeps its colours, and will not respond to
  #   colorways
  #
  # Scaling is uniform only. An illustration can still lend its outline as
  # a spine for type to follow.
  class Illustration
    SHAPES = %w[path rect circle ellipse polygon polyline].freeze
    SKIPPED = %w[defs clipPath mask symbol metadata title desc style script].freeze

    attr_reader :path, :fills, :markup, :view_box

    def self.from_file(file, **options) = new(File.read(file), **options)

    # svg: the document as a string. slot and name are the artwork's when
    # placed without saying otherwise.
    def initialize(svg, name: nil)
      @name = name
      document = REXML::Document.new(svg)
      root = document.root
      raise ArgumentError, "not an SVG document" unless root&.name == "svg"

      @view_box = root.attributes["viewBox"]&.split(/[\s,]+/)&.map(&:to_f)
      @fills = []
      @path = Geometry::Path.new(collect(root, Geometry::Affine.identity))
      raise ArgumentError, "the artwork has no filled geometry" if @path.empty?

      @fills = @fills.uniq.freeze
      @markup = root.children.map(&:to_s).join.strip
    end

    def name = @name
    def monochrome? = fills.size <= 1
    def multicolor? = !monochrome?
    def uniform_only? = true

    # Ink bounds: what was drawn, not the viewBox.
    def bounds(tolerance: 0.1) = path.bounds(tolerance: tolerance)
    def ink_bounds(tolerance: 0.1) = bounds(tolerance: tolerance)
    def ink_width = bounds.then { |a, b| b.x - a.x }
    def ink_height = bounds.then { |a, b| b.y - a.y }

    # Uniform only. Non-uniform scaling of artwork is locked off.
    def scale_by(factor)
      raise ArgumentError, "scale factor must be positive" unless factor.positive?

      transform(Geometry::Affine.scale(factor))
    end

    def transform(affine)
      copy = dup
      copy.instance_variable_set(:@path, path.transform(affine))
      copy.instance_variable_set(:@markup, %(<g transform="#{affine.to_svg}">#{markup}</g>))
      copy
    end

    # Spines of the artwork's contours, largest first, for type to follow.
    def spines
      @spines ||= path.subpaths.map(&:spine).sort_by { |s| -Geometry::Offset.signed_area(s.flatten).abs }
    end

    def spine = spines.first

    # A container on the artwork's largest contour, with the artwork
    # attached, so regions and children can hang off it.
    def to_container(visible: false, name: nil, slot: :ink, tolerance: 0.1)
      container = Container.new(spine, visible: visible, name: name || self.name, tolerance: tolerance)
      container.attach(self, name: self.name, slot: slot)
      container
    end

    private

    def collect(element, affine)
      return [] if SKIPPED.include?(element.name)

      here = affine * parse_transform(element.attributes["transform"])
      own = SHAPES.include?(element.name) ? geometry(element, here) : []
      own + element.elements.flat_map { |child| collect(child, here) }
    end

    def geometry(element, affine)
      fill = fill_of(element)
      return [] if fill == "none"

      d = case element.name
          when "path" then element.attributes["d"]
          when "rect" then rect_d(element)
          when "circle" then ellipse_d(element, "r", "r")
          when "ellipse" then ellipse_d(element, "rx", "ry")
          when "polygon" then "M #{element.attributes['points']} Z"
          when "polyline" then "M #{element.attributes['points']}"
          end
      return [] if d.nil? || d.strip.empty?

      @fills << fill
      Geometry::Path.parse(d).transform(affine).subpaths
    end

    # The fill that applies, walking up the tree; SVG's default is black.
    def fill_of(element)
      node = element
      while node.is_a?(REXML::Element)
        value = node.attributes["fill"] || node.attributes["style"]&.[](/(?:^|;)\s*fill\s*:\s*([^;]+)/, 1)
        return value.strip.downcase if value && !value.strip.empty?

        node = node.parent
      end
      "#000000"
    end

    def rect_d(e)
      x = e.attributes["x"].to_f
      y = e.attributes["y"].to_f
      w = e.attributes["width"].to_f
      h = e.attributes["height"].to_f
      "M #{x} #{y} H #{x + w} V #{y + h} H #{x} Z"
    end

    def ellipse_d(e, rx_key, ry_key)
      cx = e.attributes["cx"].to_f
      cy = e.attributes["cy"].to_f
      rx = e.attributes[rx_key].to_f
      ry = e.attributes[ry_key].to_f
      "M #{cx + rx} #{cy} A #{rx} #{ry} 0 1 1 #{cx - rx} #{cy} A #{rx} #{ry} 0 1 1 #{cx + rx} #{cy} Z"
    end

    def parse_transform(value)
      return Geometry::Affine.identity if value.nil?

      value.scan(/(\w+)\s*\(([^)]*)\)/).reduce(Geometry::Affine.identity) do |acc, (kind, args)|
        n = args.split(/[\s,]+/).reject(&:empty?).map(&:to_f)
        step = case kind
               when "matrix" then Geometry::Affine.new(*n)
               when "translate" then Geometry::Affine.translate(n[0], n[1] || 0.0)
               when "scale" then Geometry::Affine.scale(n[0], n[1] || n[0])
               when "rotate"
                 r = Geometry::Affine.rotate(n[0] * Math::PI / 180.0)
                 n.size == 3 ? Geometry::Affine.translate(n[1], n[2]) * r * Geometry::Affine.translate(-n[1], -n[2]) : r
               when "skewX" then Geometry::Affine.new(1.0, 0.0, Math.tan(n[0] * Math::PI / 180.0), 1.0, 0.0, 0.0)
               when "skewY" then Geometry::Affine.new(1.0, Math.tan(n[0] * Math::PI / 180.0), 0.0, 1.0, 0.0, 0.0)
               else raise ArgumentError, "unsupported transform #{kind}"
               end
        acc * step
      end
    end
  end
end
