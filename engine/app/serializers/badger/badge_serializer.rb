# The wire format for a badge. Key order here is the key order downstream
# tools see, and the contract test pins it, so treat this file as the
# interface.
module Badger
  module BadgeSerializer
    module_function

    def summary(badge)
      { id: badge.id, name: badge.name, slots: badge.slot_count, colorways: badge.colorways.count }
    end

    # The document, and what rendering it measures: the output contract,
    # less the geometry, which is what the .svg route is for.
    def one(badge)
      output = badge.output
      summary(badge).merge(
        spec: badge.spec,
        ink_bounds: output.to_h[:ink_bounds],
        optical_center: output.to_h[:optical_center],
        anchors: output.to_h[:anchors],
        container: output.container_path.to_d,
        slot_list: output.slots.map { |s| { rank: s.rank, name: s.name, property: s.property, value: s.value } },
        pieces: output.pieces.map { |p| { kind: p.kind, name: p.name, slot: p.rank, depth: p.depth } }
      )
    end

    def many(badges)
      badges.map { |badge| summary(badge) }
    end
  end
end
