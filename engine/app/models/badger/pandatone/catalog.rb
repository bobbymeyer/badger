# Every palette Pandatone has, fetched once and filtered here. Held in the
# process for a few minutes: a handful of value objects for one person's
# tool, and a catalogue that silently did nothing would look exactly like
# one that worked.
module Badger
  module Pandatone
    class Catalog
      CACHE_FOR = 5.minutes

      class << self
        def current(source = Badger.palette_source)
          forget! if @fetched_at.nil? || @fetched_at < CACHE_FOR.ago

          @current ||= new(source).tap { @fetched_at = Time.current }
        end

        def forget!
          @current = @fetched_at = nil
        end
      end

      def initialize(source)
        @source = source
      end

      def palettes
        @palettes ||= Array(@source.call).map { |json| Palette.from_json(json.deep_stringify_keys) }
      end

      def serving(slot_count)
        palettes.select { |palette| palette.serves?(slot_count) }
      end
    end
  end
end
