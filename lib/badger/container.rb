# frozen_string_literal: true

module Badger
  # A container: a closed path (imported or primitive) that derives regions.
  # Regions are optional and per-container; an invisible container is a
  # construction line that still derives regions and, later, anchors
  # children. Step 5 adds the tree; this is one node of it.
  class Container
    attr_reader :spine, :regions, :name, :tolerance

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
      @offsets = { 0.0 => @spine }
    end

    def visible? = @visible
    def path = spine.to_path
    def length = spine.length

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

    private

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
