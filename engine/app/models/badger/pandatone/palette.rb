# A palette as Badger reads it: its colours, and the order they fall into
# when ranked by how light they look.
module Badger
  module Pandatone
    class Palette
      attr_reader :id, :name, :tags, :colors

      def self.from_json(json)
        new(id: json["id"], name: json["name"], tags: json["tags"] || [],
            colors: (json["colors"] || []).map { |color| Pandatone::Color.from_json(color) })
      end

      def initialize(id:, name:, tags: [], colors: [])
        @id, @name, @tags, @colors = id, name, tags, colors
      end

      def size = colors.size

      # Lightest first: slot 0 is the ground, and paper ranks above ink.
      # Name and id break a tie, so two colours of equal lightness never
      # swap between renders.
      def ranked
        @ranked ||= colors.sort_by { |color| [ -color.luminance, color.name.to_s, color.id.to_i ] }
      end

      # Every slot needs a colour before the ranks mean anything.
      def serves?(slot_count) = size >= slot_count
    end
  end
end
