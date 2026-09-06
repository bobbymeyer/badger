module Badger
  module Api
    module V1
      # The API's own description. Open on purpose: it says what the doors
      # are, not what is behind them.
      class OpenapiController < ActionController::API
        def show
          render json: Badger.openapi
        end
      end
    end
  end
end
