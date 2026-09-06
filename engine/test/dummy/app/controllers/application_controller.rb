# The host's door, in the smallest form that still is one: every screen is
# refused until a cookie says you are in. A real host authenticates a session
# here; the engine inherits whatever it does.
class ApplicationController < ActionController::Base
  before_action :require_authentication

  private
    def require_authentication
      head :unauthorized unless cookies[:signed_in] == "yes"
    end
end
