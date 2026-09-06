module Badger
  module Api
    module V1
      class ColorwaysController < BaseController
        def index
          render json: Badger.colorways
        end

        def show
          colorway = Colorway.find(params[:id])
          respond_to do |format|
            format.json { render json: Badger.colorway(colorway.id) }
            format.svg { render plain: colorway.svg(padding: padding), content_type: "image/svg+xml" }
          end
        end
      end
    end
  end
end
