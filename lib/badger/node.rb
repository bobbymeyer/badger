# frozen_string_literal: true

module Badger
  # A child in a container's tree: the child plus the affine that carries
  # its local coordinates into the parent's. Children are containers, type
  # (a Setting or a Follow) or, later, illustration.
  class Node
    attr_reader :child, :affine, :name, :slot

    def initialize(child, affine, name: nil, slot: :ink)
      @child = child
      @affine = affine
      @name = name
      @slot = Slot.rank(slot)
    end

    def kind
      case child
      when Container then :container
      when Setting, Follow, Block then :type
      when Geometry::Path then :illustration
      else :unknown
      end
    end

    # The child's geometry in its own space; a bare Path is its own geometry.
    def local_path = child.is_a?(Geometry::Path) ? child : child.path

    # The child's geometry in the parent's space.
    def path = local_path.transform(affine)
    def bounds(tolerance: 0.1) = path.bounds(tolerance: tolerance)
  end

  # One drawable piece of a resolved tree, in world coordinates.
  Resolved = Data.define(:kind, :name, :path, :source, :depth, :slot)
end
