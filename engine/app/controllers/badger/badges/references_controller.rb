# The photograph a badge is redrawn from. Put on with a file, moved and
# faded from the editor, served back to the page, taken off. One per badge.
module Badger
  class Badges::ReferencesController < ApplicationController
    before_action :set_badge

    def show
      reference = @badge.reference or raise ActiveRecord::RecordNotFound
      expires_in 1.hour, public: false
      send_data reference.data, type: reference.content_type, disposition: "inline"
    end

    def create
      reference = @badge.reference || @badge.build_reference
      reference.image = params.require(:reference)[:image]
      if reference.save
        redirect_to badge_path(@badge), notice: "Reference put under #{@badge.name}."
      else
        redirect_to badge_path(@badge), alert: reference.errors.full_messages.to_sentence
      end
    end

    # Where and how strongly. Asked by the editor as it is dragged and slid,
    # so it answers JSON; a form gets the page back.
    def update
      reference = @badge.reference or raise ActiveRecord::RecordNotFound
      if reference.update(placement_params)
        respond_to do |format|
          format.json { render json: reference_json(reference) }
          format.html { redirect_to badge_path(@badge), notice: "Reference placed." }
        end
      else
        respond_to do |format|
          format.json { render json: { error: reference.errors.full_messages.to_sentence }, status: :unprocessable_content }
          format.html { redirect_to badge_path(@badge), alert: reference.errors.full_messages.to_sentence }
        end
      end
    end

    def destroy
      @badge.reference&.destroy!
      redirect_to badge_path(@badge), notice: "Reference taken off."
    end

    private
      def set_badge
        @badge = Badge.find(params[:badge_id])
      end

      def placement_params
        params.expect(reference: [ :x, :y, :scale, :opacity ])
      end

      def reference_json(reference)
        reference.slice(:x, :y, :scale, :opacity, :width, :height).merge(url: badge_reference_path(@badge))
      end
  end
end
