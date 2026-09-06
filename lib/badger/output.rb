# frozen_string_literal: true

require "json"

module Badger
  # What Badger.render returns: the output contract.
  #
  #   pieces          geometry in world space, each with kind, name and slot
  #   ink_bounds      bounds of everything drawn
  #   optical_center  area-weighted centre of everything drawn
  #   container_path  the root container's path, separately, for knockouts
  #                   against a field and silhouette reuse
  #   anchors         named points on the container, for hanging siblings
  #   slots           the ranks in use, densely numbered, with a value grey
  #                   each, unresolved until a consumer supplies colours
  #
  # Colours are never baked in. to_svg emits fills as custom properties
  # over the value grey unless a colours map is given.
  class Output
    Piece = Data.define(:kind, :name, :path, :rank, :depth) do
      def d = path.to_d
    end

    SlotInfo = Data.define(:rank, :name, :given, :value, :pieces) do
      def property = "--badger-slot-#{rank}"
    end

    attr_reader :container, :world, :pieces, :slots

    def initialize(container, world: Geometry::Affine.identity)
      @container = container
      @world = world
      resolved = container.resolve(world: world)
      ranks = resolved.map(&:slot).uniq.sort
      @pieces = resolved.map do |r|
        Piece.new(kind: r.kind, name: r.name, path: r.path, rank: ranks.index(r.slot), depth: r.depth)
      end.freeze
      @slots = ranks.each_with_index.map do |given, dense|
        SlotInfo.new(rank: dense, name: Slot.name_for(dense, ranks.size), given: given,
                     value: Value.grey(Value.lightness(dense, ranks.size)),
                     pieces: @pieces.count { |p| p.rank == dense })
      end.freeze
    end

    def geometry = pieces.map(&:path).reduce(Geometry::Path.new([]), :+)

    def ink_bounds
      @ink_bounds ||= begin
        corners = pieces.map { |p| p.path.bounds }
        [Geometry::Point.new(corners.map { |min, _| min.x }.min, corners.map { |min, _| min.y }.min),
         Geometry::Point.new(corners.map { |_, max| max.x }.max, corners.map { |_, max| max.y }.max)]
      end
    end

    def width = ink_bounds[1].x - ink_bounds[0].x
    def height = ink_bounds[1].y - ink_bounds[0].y

    # Area-weighted centroid of every drawn piece: where the badge's weight
    # sits, which is not the middle of its bounds on a shield or a crest.
    def optical_center
      @optical_center ||= begin
        total = 0.0
        sum = Geometry::Point.new(0.0, 0.0)
        pieces.each do |piece|
          piece.path.spines.each do |spine|
            polygon = spine.flatten(0.1)
            area = Geometry::Offset.signed_area(polygon).abs
            next if area < 1e-9

            sum += polygon_centroid(polygon) * area
            total += area
          end
        end
        total.positive? ? sum / total : (ink_bounds[0] + ink_bounds[1]) / 2
      end
    end

    def container_path = container.path.transform(world)

    # The nine reference points of the container's bounds plus its centroid,
    # in world space.
    def anchors
      @anchors ||= begin
        bounds = container_path.bounds
        Alignment::NAMED.keys.to_h { |name| [name, Alignment.reference(bounds, name)] }
                        .merge(centroid: world.apply(container.centroid))
      end
    end

    # Any locator resolved against the container, in world space.
    def anchor(locator) = world.apply(locator.resolve(container).point)

    # Resolve slot ranks (dense rank or slot name) to fills.
    def fills(colors = nil)
      slots.to_h do |slot|
        given = colors && (colors[slot.rank] || colors[slot.name] || colors[slot.name.to_sym])
        [slot.rank, given || "var(#{slot.property}, #{slot.value})"]
      end
    end

    def to_svg(colors: nil, padding: 0.0, precision: nil)
      min, _max = ink_bounds
      fill = fills(colors)
      f = Geometry.method(:fmt)
      body = pieces.map do |piece|
        attrs = [%(d="#{piece.d}"), %(fill="#{fill[piece.rank]}"), %(data-slot="#{piece.rank}"), %(data-kind="#{piece.kind}")]
        attrs << %(data-name="#{piece.name}") if piece.name
        "  <path #{attrs.join(' ')}/>"
      end
      viewbox = [min.x - padding, min.y - padding, width + 2 * padding, height + 2 * padding].map { |v| f.(v) }.join(" ")
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="#{viewbox}" width="#{f.(width + 2 * padding)}" height="#{f.(height + 2 * padding)}" data-badger-slots="#{slots.size}">
        #{body.join("\n")}
        </svg>
      SVG
    end

    def to_h
      min, _max = ink_bounds
      {
        ink_bounds: { x: min.x, y: min.y, width: width, height: height },
        optical_center: { x: optical_center.x, y: optical_center.y },
        container: container_path.to_d,
        anchors: anchors.transform_values { |p| { x: p.x, y: p.y } },
        slots: slots.map { |s| { rank: s.rank, name: s.name, property: s.property, value: s.value, pieces: s.pieces } },
        pieces: pieces.map { |p| { kind: p.kind, name: p.name, slot: p.rank, depth: p.depth, d: p.d } }
      }
    end

    def to_json(*args) = JSON.generate(to_h, *args)

    private

    def polygon_centroid(points)
      twice_area = 0.0
      cx = 0.0
      cy = 0.0
      points.each_index do |i|
        a = points[i]
        b = points[(i + 1) % points.size]
        cross = a.x * b.y - b.x * a.y
        twice_area += cross
        cx += (a.x + b.x) * cross
        cy += (a.y + b.y) * cross
      end
      Geometry::Point.new(cx / (3 * twice_area), cy / (3 * twice_area))
    end
  end

  # The public interface: a container tree to an Output.
  def self.render(container, world: Geometry::Affine.identity) = Output.new(container, world: world)
end
