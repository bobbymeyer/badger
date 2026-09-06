# frozen_string_literal: true

require_relative "badger/version"

module Badger
  class Error < StandardError; end
end

require_relative "badger/geometry"
require_relative "badger/tracking"
require_relative "badger/follow"
