# Somewhere public to land, rendered through the shell like every other
# page, so a browser test can plant its cookie on a page whose scripts have
# started.
class HomeController < ApplicationController
  skip_before_action :require_authentication

  def show
  end
end
