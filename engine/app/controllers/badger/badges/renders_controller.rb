# The editor's round trip: a document in, the drawing and its construction
# out, nothing saved. What the badge page shows on load is the same answer
# for the stored document, so the editor and the page cannot disagree.
module Badger
  class Badges::RendersController < ApplicationController
    before_action :set_badge

    def create
      document = params.require(:document).permit!.to_h
      render json: Badge.new(name: @badge.name, spec: document).rendering
    rescue Badger::Spec::Error, Badger::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private
      def set_badge
        @badge = Badge.find(params[:id])
      end
  end
end
