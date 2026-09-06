# v1, versioned from the first commit for the reason Pandatone's is: other
# tools depend on this contract, and the way to change it is to add v2.
#
# Read-only. Badges are composed in the editor; this is for the tools that
# consume them. Every endpoint inherits from the host's API controller,
# which decides who may call it.
module Badger
  module Api
    module V1
      class BaseController < Badger.api_base_controller_class.constantize
        include ActionController::MimeResponds

        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

        private
          def render_not_found
            render json: { error: "Not found" }, status: :not_found
          end

          # Room around the ink, in badge units. The one thing a consumer
          # needs that the badge does not already say.
          def padding
            params[:padding].presence&.to_f&.clamp(0, 400) || 0
          end
      end
    end
  end
end
