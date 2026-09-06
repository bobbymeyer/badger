# frozen_string_literal: true

require_relative "badger/version"

module Badger
  class Error < StandardError; end
end

require_relative "badger/geometry"
require_relative "badger/sidecar"
require_relative "badger/font"
require_relative "badger/tracking"
require_relative "badger/follow"
require_relative "badger/slot"
require_relative "badger/regions"
require_relative "badger/locator"
require_relative "badger/alignment"
require_relative "badger/node"
require_relative "badger/container"
require_relative "badger/setting"
require_relative "badger/fit"
require_relative "badger/booleans"
require_relative "badger/effects"
require_relative "badger/block"
require_relative "badger/output"
