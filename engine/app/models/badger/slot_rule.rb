# What one of a badge's colour slots resolves to. A rule, not an assignment:
# a colorway that stored hexes would be wrong the moment the badge under it
# changed, and a rule is still right.
module Badger
  class SlotRule < ApplicationRecord
    KINDS = %w[ auto_value_match assigned_slot ].freeze

    belongs_to :colorway, inverse_of: :rules

    KINDS.each { |name| define_method("#{name}?") { kind == name } }

    validates :kind, inclusion: { in: KINDS }
    validates :slot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    attribute :settings, default: -> { {} }
    store_accessor :settings, :index

    validate :index_fits_the_palette

    # Auto value match reads the slot's rank on the badge's ladder against
    # the palette's lightness ranks, both ends kept when the palette has
    # more colours than the badge has slots. Assigned slot names a position
    # in the palette's own order.
    def color_for(slot_count)
      palette = colorway.snapshot.palette
      case kind
      when "auto_value_match"
        return nil if palette.size.zero?

        rank = slot_count <= 1 ? palette.size - 1 : (slot * (palette.size - 1)).fdiv(slot_count - 1).round
        palette.ranked[rank]
      when "assigned_slot"
        palette.colors[index.to_i % [ palette.size, 1 ].max]
      end
    end

    def binds_to_rank? = auto_value_match?

    private
      def index_fits_the_palette
        return unless assigned_slot?
        return if colorway.nil? || colorway.snapshot.nil?

        size = colorway.snapshot.size
        return if index.is_a?(Integer) && index.between?(0, size - 1)

        errors.add(:index, "has to name one of the palette's #{size} colours")
      end
  end
end
