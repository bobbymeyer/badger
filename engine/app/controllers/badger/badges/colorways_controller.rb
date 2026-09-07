# Dressing a badge in one of Pandatone's palettes. Choosing is the only part
# that needs Pandatone at all; a colorway renders from its snapshot
# afterwards. The asking is Pandatone's dresser's; what is here is the
# badge's side of it.
module Badger
  class Badges::ColorwaysController < ApplicationController
    include Pandatone::Dresser::Dressing

    before_action :set_badge

    # The palette picker: every palette Pandatone has, the ones that can
    # dress this badge first — demoted and not excluded, because a slot
    # taken out of the document brings the rest back into range.
    def new
      @serving, @demoted = catalog.palettes.partition { |palette| palette.serves?(@badge.slot_count) }
    rescue Pandatone::Dresser::Error => e
      @unreachable = e
    end

    def create
      palette = palette_from_catalog(params[:palette_id])
      return redirect_to(new_badge_colorway_path(@badge), alert: "That palette is not in the catalogue.") if palette.nil?

      colorway = @badge.colorways.build(palette: palette)
      if colorway.save
        redirect_to dress(colorway), notice: "#{@badge.name} dressed in #{palette.name}."
      else
        redirect_to new_badge_colorway_path(@badge), alert: colorway.errors.full_messages.to_sentence
      end
    rescue Pandatone::Dresser::Error => e
      redirect_to new_badge_colorway_path(@badge), alert: "Pandatone could not be asked: #{e.message}"
    end

    # Bind one rank to a rule: by rank (the default) or to a position in the
    # palette.
    def update
      colorway = @badge.colorways.find(params[:id])
      rank = params[:rank].to_i
      if params[:kind] == "assigned_slot"
        colorway.bind(rank, kind: "assigned_slot", slot: params[:slot].to_i)
      else
        colorway.rules.where(rank: rank).destroy_all
      end
      redirect_to dress(colorway), notice: "Slot #{rank} bound."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to dress(params[:id]), alert: e.message
    end

    # Reported, never applied.
    def drift
      colorway = @badge.colorways.find(params[:id])
      redirect_to dress(colorway), notice: drift_report(colorway)
    rescue Pandatone::Dresser::Error => e
      redirect_to dress(params[:id]), alert: "Pandatone could not be asked: #{e.message}"
    end

    def destroy
      colorway = @badge.colorways.find(params[:id])
      colorway.destroy!
      redirect_to badge_path(@badge, section: "dress"), notice: "#{colorway.palette_name} taken off."
    end

    private
      def set_badge
        @badge = Badge.find(params[:badge_id])
      end

      # Back to the surface the colorways live on, wearing this one.
      def dress(colorway)
        badge_path(@badge, colorway: colorway, section: "dress")
      end
  end
end
