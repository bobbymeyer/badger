module Badger
  module Api
    module V1
      class BadgesController < BaseController
        before_action :set_badge, only: :show

        def index
          render json: Badger.badges
        end

        # JSON for the document and the output contract's measurements; svg
        # for the geometry, fills unresolved unless `?colorway=` dresses it.
        def show
          respond_to do |format|
            format.json { render json: Badger.badge(@badge.id) }
            format.svg do
              svg = Badger.badge_svg(@badge.id, colorway: params[:colorway], padding: padding)
              render plain: svg, content_type: "image/svg+xml"
            end
          end
        end

        private
          def set_badge
            @badge = Badge.friendly(params[:key]) or raise ActiveRecord::RecordNotFound
          end
      end
    end
  end
end
