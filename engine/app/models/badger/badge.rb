require "yaml"

module Badger
  # A badge is its document: the container tree, regions, type and artwork
  # as Badger::Spec reads them. Everything drawn is derived from it at
  # render time, so the record holds nothing that the document does not.
  class Badge < ApplicationRecord
    has_many :colorways, dependent: :destroy, inverse_of: :badge

    before_validation :strip_name

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validate :spec_builds

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
      self.spec = YAML.safe_load(text.to_s, permitted_classes: [], aliases: false) || {}
    rescue Psych::SyntaxError => e
      @yaml_error = e.message
    end

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
