require "yaml"

module Badger
  # A badge is its document: the container tree, regions, type and artwork
  # as Badger::Spec reads them. Everything drawn is derived from it at
  # render time, so the record holds nothing that the document does not.
  class Badge < ApplicationRecord
    has_many :colorways, dependent: :destroy, inverse_of: :badge
    has_one :reference, dependent: :destroy, inverse_of: :badge

    before_validation :strip_name

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validate :spec_builds

    # What the index narrows by: a name as typed, whether a palette has been
    # chosen, and the orders the sort register offers.
    scope :name_matching, ->(q) { q.present? ? where("LOWER(#{table_name}.name) LIKE ?", "%#{sanitize_sql_like(q.to_s.downcase)}%") : all }
    scope :wearing, ->(state) {
      case state.to_s
      when "dressed" then where(id: Colorway.select(:badge_id))
      when "undressed" then where.not(id: Colorway.select(:badge_id))
      else all
      end
    }

    SORTS = { "name" => "Name", "newest" => "Newest" }.freeze
    WEARING = { "dressed" => "Dressed", "undressed" => "In value" }.freeze

    scope :sorted, ->(key) { key.to_s == "newest" ? order(created_at: :desc, name: :asc) : order(:name) }

    # Addressable by name as well as id: a consuming tool asking for
    # "Stockholm" should not have to look an id up first.
    def self.friendly(key)
      key = key.to_s.strip
      return nil if key.blank?

      where("#{table_name}.id = :id OR LOWER(#{table_name}.name) = :name",
        id: Integer(key, exception: false), name: key.downcase).first
    end

    # The document, edited as YAML. Reading gives the stored document in
    # YAML; writing parses it, and a document that does not parse is kept
    # as text so the error can be shown beside what was typed.
    def spec_yaml
      @spec_yaml || (spec.presence && spec.to_yaml.delete_prefix("---\n"))
    end

    def spec_yaml=(text)
      @spec_yaml = text
      @yaml_error = nil
      parsed = YAML.safe_load(text.to_s, permitted_classes: [], aliases: false) || {}
      @yaml_error = "the document is a #{parsed.class.name.downcase}, not a mapping of keys to values" unless parsed.is_a?(Hash)
      self.spec = parsed.is_a?(Hash) ? parsed : {}
    rescue Psych::SyntaxError => e
      @yaml_error = e.message
    end

    # Why the last YAML written did not parse, or nil.
    attr_reader :yaml_error

    def container
      @container ||= Badger::Spec.build(spec || {})
    end

    def output(world: Badger::Geometry::Affine.identity)
      Badger.render(container, world: world)
    end

    def svg(colors: nil, padding: 0)
      output.to_svg(colors: colors, padding: padding.to_f)
    end

    def slots
      output.slots
    end

    # Everything the editor draws from, in one answer: the drawing with room
    # around it, the construction under it, what went wrong without failing,
    # the slots and the ink. Padding is the editor's, so a handle at the
    # edge of the ink has somewhere to be.
    PADDING = 12.0

    def rendering
      out = output
      { svg: out.to_svg(padding: PADDING), construction: out.construction, warnings: out.warnings,
        slots: out.slots.map { |s| { rank: s.rank, name: s.name, value: s.value, pieces: s.pieces } },
        ink: { x: out.ink_bounds[0].x, y: out.ink_bounds[0].y, width: out.width, height: out.height }, padding: PADDING }
    end

    def slot_count
      slots.size
    end

    def reload(*)
      @container = @spec_yaml = @yaml_error = nil
      super
    end

    private
      def strip_name
        self.name = name.strip if name.is_a?(String)
      end

      # The document is validated by building it: every error Badger::Spec
      # raises names where in the document it is and what is wrong.
      def spec_builds
        return errors.add(:spec, "is not YAML: #{@yaml_error}") if @yaml_error
        return errors.add(:spec, "is empty") if spec.blank?

        @container = nil
        container
      rescue Badger::Spec::Error, Badger::Error => e
        errors.add(:spec, e.message)
      end
  end
end
