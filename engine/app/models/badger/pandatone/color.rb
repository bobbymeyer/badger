# One of Pandatone's colours, as far as Badger cares: something to put in a
# slot, and a measure of how light it looks so the palette can be ranked.
module Badger
  module Pandatone
    class Color
      attr_reader :id, :name, :hex, :red, :green, :blue, :tags

      def self.from_json(json)
        rgb = json["rgb"] || {}
        new(id: json["id"], name: json["name"], hex: json["hex"], tags: json["tags"] || [],
            red: rgb["r"], green: rgb["g"], blue: rgb["b"])
      end

      def initialize(id:, name:, hex:, red: nil, green: nil, blue: nil, tags: [])
        @id, @name, @hex, @tags = id, name, hex, tags
        @red, @green, @blue = red, green, blue
      end

      def luminance
        @luminance ||= red && green && blue ? Luminance.of(red, green, blue) : Luminance.of_hex(hex)
      end

      def to_h
        { "id" => id, "name" => name, "hex" => hex, "rgb" => { "r" => red, "g" => green, "b" => blue }, "tags" => tags }
      end

      def ==(other)
        other.is_a?(Pandatone::Color) && id == other.id && hex == other.hex
      end
      alias eql? ==

      def hash = [ id, hex ].hash
    end
  end
end
