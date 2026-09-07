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
    attr_reader :spine, :regions, :name, :tolerance, :nodes, :slot, :address

    # source:    a Geometry::Path (first subpath is used), Spine or Ellipse
    # visible:   whether the container's own silhouette renders
    # slot:      colour slot of the silhouette; the ground by default
    # tolerance: flattening tolerance for derived offsets
    # address:   where in a document this container was written
    def initialize(source, visible: true, name: nil, slot: :ground, tolerance: 0.1, address: nil)
      @spine = spine_from(source)
      raise ArgumentError, "a container needs a closed path" unless @spine.closed?

      @visible = visible
      @name = name
      @slot = Slot.rank(slot)
      @tolerance = tolerance
      @address = address
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
    def rule(distance, weight: 2.0, visible: true, name: nil, slot: :ink, address: nil)
      add Regions::Offset.new(self, distance: distance, weight: weight, visible: visible, name: name, slot: slot,
                              address: address)
    end

    # An annulus between two offsets, given as outer/inner distances or an
    # outer distance and a width measured inward from it.
    def band(outer:, inner: nil, width: nil, visible: false, name: nil, slot: :field, address: nil)
      raise ArgumentError, "give inner: or width:, not both" if inner && width
      raise ArgumentError, "a band needs inner: or width:" unless inner || width

      inner ||= outer - width
      add Regions::Band.new(self, outer: outer, inner: inner, visible: visible, name: name, slot: slot, address: address)
    end

    # What remains inside the innermost offset.
    def interior(inside: 0.0, visible: false, name: nil, slot: :field, address: nil)
      add Regions::Interior.new(self, inside: inside, visible: visible, name: name, slot: slot, address: address)
    end

    def visible_regions = regions.select(&:visible?)

    # --- the tree -----------------------------------------------------------

    # Anchor a child (a Container, Setting, Follow or Path) in this
    # container's space. `at` is a Locator; `align` names which of the
    # child's reference points lands on it. `rotate` is nil, :tangent (the
    # locator's own direction: the path tangent or the polar radial) or an
    # angle in degrees; rotation is about the reference point.
    def place(child, at:, align: :center, rotate: nil, name: nil, slot: :ink, address: nil, construction: nil)
      anchor = at.resolve(self)
      reference = Alignment.reference(child_bounds(child), align)
      radians = rotation_for(rotate, anchor, at)
      affine = Geometry::Affine.translate(anchor.point.x, anchor.point.y) *
               Geometry::Affine.rotate(radians) *
               Geometry::Affine.translate(-reference.x, -reference.y)
      add_node Node.new(child, affine, name: name, slot: slot, address: address, anchor: anchor.point,
                        construction: construction)
    end

    # Attach a child already expressed in this container's space, such as
    # type following one of this container's own regions.
    def attach(child, name: nil, slot: :ink, address: nil, construction: nil)
      add_node Node.new(child, Geometry::Affine.identity, name: name, slot: slot, address: address,
                        construction: construction)
    end

    def children = nodes.map(&:child)

    # Every drawable piece of this container and its descendants in world
    # space, outside-in: the silhouette, then visible regions, then
    # children in placement order.
    def resolve(world: Geometry::Affine.identity, depth: 0)
      out = []
      if visible?
        out << Resolved.new(kind: :container, name: name, path: path.transform(world), source: self, depth: depth,
                            slot: slot, affine: world, markup: nil, address: address)
      end
      visible_regions.each do |region|
        out << Resolved.new(kind: :region, name: region.name, path: region.path.transform(world), source: region,
                            depth: depth, slot: region.slot, affine: world, markup: nil, address: region.address)
      end
      nodes.each do |node|
        local = world * node.affine
        case node.child
        when Container
          out.concat(node.child.resolve(world: local, depth: depth + 1))
        else
          out << Resolved.new(kind: node.kind, name: node.name, path: node.local_path.transform(local),
                              source: node.child, depth: depth + 1, slot: node.slot, affine: local, markup: node.markup,
                              address: node.address)
        end
      end
      out
    end

    # What an editor draws over the pieces: the whole tree's construction in
    # world space, visible or not. Every container's silhouette and centroid;
    # every region's edges; for type that follows, the baseline it sits on,
    # the sweep it was given and the run it took, as points and as visual
    # degrees from the container's centroid; for type that was fitted, the
    # chord it was fitted to; for a placed child, the point it was put at.
    # Each entry carries the address of the document entry it came from.
    def construction(world: Geometry::Affine.identity)
      out = []
      d = ->(path) { path.transform(world).to_d }
      center = world.apply(centroid)
      out << { kind: "container", address: address, name: name, visible: visible?, d: d.(path),
               centroid: { x: center.x, y: center.y } }
      regions.each do |region|
        entry = { kind: region.class.name.split("::").last.downcase, address: region.address, name: region.name,
                  visible: region.visible? }
        case region
        when Regions::Offset
          entry.merge!(kind: "rule", d: d.(region.spine.to_path(tolerance: tolerance)), distance: region.distance, weight: region.weight)
        when Regions::Band
          entry.merge!(kind: "band", outer_d: d.(region.outer_edge.to_path(tolerance: tolerance)),
                       inner_d: d.(region.inner_edge.to_path(tolerance: tolerance)),
                       outer: region.outer, inner: region.inner, width: region.width)
        when Regions::Interior
          entry.merge!(d: d.(region.path), inside: region.inside)
        end
        out << entry
      end
      nodes.each do |node|
        local = world * node.affine
        case node.child
        when Container
          out.concat(node.child.construction(world: local))
        when Follow
          out << follow_construction(node, world, center)
        else
          entry = { kind: node.kind.to_s, address: node.address, name: node.name }
          entry[:anchor] = world.apply(node.anchor).then { |p| { x: p.x, y: p.y } } if node.anchor
          (node.construction || {}).each { |key, path| entry[key] = path.transform(world).to_d }
          out << entry
        end
      end
      out
    end

    private

    # The sweep's ends and the run's ends, as points on the baseline and as
    # visual degrees from the container's centroid: what a handle drags.
    def follow_construction(node, world, center)
      follow = node.child
      spine = follow.spine
      point = ->(s) { world.apply(spine.point_at(s)) }
      degrees = ->(p) { (Math.atan2(p.y - center.y, p.x - center.x) * 180.0 / Math::PI) % 360.0 }
      sweep_from = point.(follow.start)
      sweep_to = point.(follow.start + follow.sweep)
      run_from = point.(follow.origin)
      run_to = point.(follow.origin + follow.run_length)
      { kind: "follow", address: node.address, name: node.name, d: spine.to_path(tolerance: tolerance).transform(world).to_d,
        sweep: { from: { x: sweep_from.x, y: sweep_from.y, degrees: degrees.(sweep_from) },
                 to: { x: sweep_to.x, y: sweep_to.y, degrees: degrees.(sweep_to) } },
        run: { from: { x: run_from.x, y: run_from.y }, to: { x: run_to.x, y: run_to.y } },
        letters: follow.placements.map { |pl| world.apply(pl.point).then { |p| { x: p.x, y: p.y } } },
        tracking: follow.tracking, align: follow.align.to_s, fits: follow.fits?, overflow: follow.overflow }
    end

    public

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
