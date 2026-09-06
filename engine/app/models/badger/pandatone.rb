# Pandatone is the colour tool. Badger composes in value and asks Pandatone
# what those values are wearing, the way Stripeclub does.
#
# Every failure here is its own class rather than a nil, because each would
# otherwise arrive as "Pandatone has no palettes".
module Badger
  module Pandatone
    Error = Class.new(StandardError)
    Unauthorized = Class.new(Error)
    NotFound = Class.new(Error)
    Unreachable = Class.new(Error)
  end
end
