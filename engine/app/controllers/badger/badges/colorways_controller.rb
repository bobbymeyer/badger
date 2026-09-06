# Dressing a badge in one of Pandatone's palettes. Choosing is the only part
# that needs Pandatone at all; a colorway renders from its snapshot afterwards.
module Badger
  class Badges::ColorwaysController < ApplicationController
    before_action :set_badge

    # The palette picker: every palette Pandatone has that can dress this
    # badge, ranked strips, chosen on the ladder.
    def new
      Pandatone::Catalog.forget! if params[:refresh]
      @catalog = Pandatone::Catalog.current
      @palettes = @catalog.serving(@badge.slot_count)
    rescue Pandatone::Error => e
      @palettes = []
      flash.now[:alert] = "Pandatone could not be asked: #{e.message}"
    end

    def create
      palette = Pandatone::Catalog.current.palettes.find { |candidate| candidate.id == params[:palette_id].to_i }
      return redirect_to(new_badge_colorway_path(@badge), alert: "That palette is not in the catalogue.") if palette.nil?

      colorway = @badge.colorways.build(palette: palette)
      if colorway.save
        redirect_to badge_path(@badge, colorway: colorway), notice: "#{@badge.name} dressed in #{palette.name}."
      else
        redirect_to new_badge_colorway_path(@badge), alert: colorway.errors.full_messages.to_sentence
      end
    rescue Pandatone::Error => e
      redirect_to new_badge_colorway_path(@badge), alert: "Pandatone could not be asked: #{e.message}"
    end

    # Bind one slot to a rule: by rank (the default) or to a palette index.
    def update
      colorway = @badge.colorways.find(params[:id])
      slot = params[:slot].to_i
      if params[:kind] == "assigned_slot"
        colorway.bind(slot, kind: "assigned_slot", index: params[:index].to_i)
      else
        colorway.rules.where(slot: slot).destroy_all
      end
      redirect_to badge_path(@badge, colorway: colorway), notice: "Slot #{slot} bound."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to badge_path(@badge, colorway: params[:id]), alert: e.message
    end

    # Whether the palette has moved since the snapshot. Asked for, not checked
    # on every page load.
    def drift
      colorway = @badge.colorways.find(params[:id])
      Pandatone::Catalog.forget!
      live = Pandatone::Catalog.current.palettes.find { |palette| palette.id == colorway.palette_id }
      message = if live.nil? then "Pandatone no longer has that palette. The snapshot is all there is of it now."
      elsif colorway.snapshot.drifted_from?(live) then "#{live.name} has moved in Pandatone since this snapshot. Nothing here has changed."
      else "#{live.name} is as it was."
      end
      redirect_to badge_path(@badge, colorway: colorway), notice: message
    rescue Pandatone::Error => e
      redirect_to badge_path(@badge, colorway: params[:id]), alert: "Pandatone could not be asked: #{e.message}"
    end

    def destroy
      colorway = @badge.colorways.find(params[:id])
      colorway.destroy!
      redirect_to badge_path(@badge), notice: "#{colorway.palette_name} taken off."
    end

    private
      def set_badge
        @badge = Badge.find(params[:badge_id])
      end
  end
end
