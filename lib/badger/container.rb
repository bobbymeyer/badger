# frozen_string_literal: true

module Badger
  # A container: a closed path (imported or primitive) that derives regions
  # and anchors children. Regions are optional and per-container; an
  # invisible container is a construction line that still derives regions
  # and still anchors children.
  #
  # Containers form a tree. A child's coordinates are its own; `place`
  # computes the affine into the parent from a locator (a point in the
  # parent's space) and an alignment (which of the child's nine reference
  # points lands there). Resolution is outside-in: `resolve` walks the tree
  # under a world transform, so the whole badge moves and scales as one.
  class Container
    attr_reader :spine, :regions, :name, :tolerance, :nodes

    # source:    a Geometry::Path (first subpath is used), Spine or Ellipse
    # visible:   whether the container's own silhouette renders
    # tolerance: flattening tolerance for derived offsets
    def initialize(source, visible: true, name: nil, tolerance: 0.1)
      @spine = spine_from(source)
      raise ArgumentError, "a container needs a closed path" unless @spine.closed?

      @visible = visible
      @name = name
      @tolerance = tolerance
      @regions = []
      @nodes = []
      @offsets = { 0.0 => @spine }
    end

    def visible? = @visible
    def path = spine.to_path
    def length = spine.length
    def bounds = (@bounds ||= path.bounds(tolerance: tolerance))
    def centroid = (@centroid ||= Regions::Interior.new(self, inside: 0.0, visible: false, name: nil).centroid)

    # The container path offset by `distance` (positive outward), memoized
    # so regions sharing an edge share the geometry.
    def offset(distance)
      @offsets[distance.to_f] ||= spine.offset(distance.to_f, tolerance: tolerance)
    end

    # --- region derivation --------------------------------------------------

    # A rule: the container path offset by `distance`, drawn `weight` thick.
    def rule(distance, weight: 2.0, visible: true, name: nil)
      add Regions::Offset.new(self, distance: distance, weight: weight, visible: visible, name: name)
    end

    # An annulus between two offsets, given as outer/inner distances or an
    # outer distance and a width measured inward from it.
    def band(outer:, inner: nil, width: nil, visible: false, name: nil)
      raise ArgumentError, "give inner: or width:, not both" if inner && width
      raise ArgumentError, "a band needs inner: or width:" unless inner || width

      inner ||= outer - width
      add Regions::Band.new(self, outer: outer, inner: inner, visible: visible, name: name)
    end

    # What remains inside the innermost offset.
    def interior(inside: 0.0, visible: false, name: nil)
      add Regions::Interior.new(self, inside: inside, visible: visible, name: name)
    end

    def visible_regions = regions.select(&:visible?)

    # --- the tree -----------------------------------------------------------

    # Anchor a child (a Container, Setting, Follow or Path) in this
    # container's space. `at` is a Locator; `align` names which of the
    # child's reference points lands on it. `rotate` is nil, :tangent (the
    # locator's own direction: the path tangent or the polar radial) or an
    # angle in degrees; rotation is about the reference point.
    def place(child, at:, align: :center, rotate: nil, name: nil)
      anchor = at.resolve(self)
      reference = Alignment.reference(child_bounds(child), align)
      radians = rotation_for(rotate, anchor, at)
      affine = Geometry::Affine.translate(anchor.point.x, anchor.point.y) *
               Geometry::Affine.rotate(radians) *
               Geometry::Affine.translate(-reference.x, -reference.y)
      add_node Node.new(child, affine, name: name)
    end

    # Attach a child already expressed in this container's space, such as
    # type following one of this container's own regions.
    def attach(child, name: nil)
      add_node Node.new(child, Geometry::Affine.identity, name: name)
    end

    def children = nodes.map(&:child)

    # Every drawable piece of this container and its descendants in world
    # space, outside-in: the silhouette, then visible regions, then
    # children in placement order.
    def resolve(world: Geometry::Affine.identity, depth: 0)
      out = []
      out << Resolved.new(kind: :container, name: name, path: path.transform(world), source: self, depth: depth) if visible?
      visible_regions.each do |region|
        out << Resolved.new(kind: :region, name: region.name, path: region.path.transform(world), source: region, depth: depth)
      end
      nodes.each do |node|
        local = world * node.affine
        case node.child
        when Container
          out.concat(node.child.resolve(world: local, depth: depth + 1))
        else
          out << Resolved.new(kind: node.kind, name: node.name, path: node.local_path.transform(local),
                              source: node.child, depth: depth + 1)
        end
      end
      out
    end

    private

    def add_node(node)
      @nodes << node
      node
    end

    def child_bounds(child)
      raise ArgumentError, "cannot place a #{child.class}; it has no bounds" unless child.respond_to?(:bounds)

      child.bounds
    end

    def rotation_for(rotate, anchor, locator)
      case rotate
      when nil then 0.0
      when :tangent
        raise ArgumentError, "#{locator} has no direction to rotate to" unless anchor.angle

        anchor.angle
      when Numeric then rotate * Math::PI / 180.0
      else raise ArgumentError, "rotate: must be nil, :tangent or degrees"
      end
    end

    def add(region)
      @regions << region
      region
    end

    def spine_from(source)
      case source
      when Geometry::Spine then source
      when Geometry::Ellipse then source.spine
      when Geometry::Path then source.spine
      else raise ArgumentError, "cannot build a container from #{source.class}"
      end
    end
  end
end
