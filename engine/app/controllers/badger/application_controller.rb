module Badger
  # Every screen in the engine. It inherits from the host's controller so the
  # host's door is the engine's too, and the engine never learns what a user is.
  class ApplicationController < Badger.base_controller_class.constantize
  end
end
