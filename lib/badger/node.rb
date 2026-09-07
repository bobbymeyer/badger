# frozen_string_literal: true

module Badger
  # A child in a container's tree: the child plus the affine that carries
  # its local coordinates into the parent's. Children are containers, type
  # (a Setting or a Follow) or, later, illustration.
  class Node
    attr_reader :child, :affine, :name, :slot, :address, :anchor, :construction

    # address:      where in a document this child was written
    # anchor:       the point in the parent's space a placed child was put
    #               at, or nil for a child attached in the parent's space
    # construction: geometry in the parent's space an editor should draw
    #               with the child — a chord it was fitted to, say — as a
    #               hash of named path data strings
    def initialize(child, affine, name: nil, slot: :ink, address: nil, anchor: nil, construction: nil)
      @child = child
      @affine = affine
      @name = name
      @slot = Slot.rank(slot)
      @address = address
      @anchor = anchor
      @construction = construction
    end

    def kind
      case child
      when Container then :container
      when Setting, Follow, Block then :type
      when Geometry::Path, Illustration then :illustration
      else :unknown
      end
    end

    # The child's geometry in its own space; a bare Path is its own geometry.
    def local_path = child.is_a?(Geometry::Path) ? child : child.path

    # Multi-colour artwork keeps its own markup instead of a slot.
    def markup = child.is_a?(Illustration) && child.multicolor? ? child.markup : nil

    # The child's geometry in the parent's space.
    def path = local_path.transform(affine)
    def bounds(tolerance: 0.1) = path.bounds(tolerance: tolerance)
  end

  # One drawable piece of a resolved tree, in world coordinates.
  Resolved = Data.define(:kind, :name, :path, :source, :depth, :slot, :affine, :markup, :address)
end
