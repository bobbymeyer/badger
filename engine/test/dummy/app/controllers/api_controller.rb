# The host's API door: one token, sent as a Bearer, and a 401 in the API's
# own envelope to everyone else. A real host looks the token up; the engine
# inherits whatever it does.
class ApiController < ActionController::API
  before_action :authenticate_client

  private
    def authenticate_client
      token, _options = ActionController::HttpAuthentication::Token.token_and_options(request)

      render json: { error: "Unauthorized" }, status: :unauthorized unless token == Dummy::API_TOKEN
    end
end
