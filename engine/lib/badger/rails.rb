# The engine's entry point; the core gem is required by name. The public
# interface another tool may call is on the Badger module below: plain
# arguments in, plain data out, the same hashes the JSON API sends.
#
#   Badger.badges                       # => [ { id:, name:, slots: }, ... ]
#   Badger.badge("Stockholm")           # => { id:, name:, spec:, slots:, ink_bounds:, ... }
#   Badger.badge_svg("Stockholm")       # => "<svg ...>", fills unresolved
#   Badger.badge_svg("Stockholm", colorway: 3)
#   Badger.colorways                    # => [ { id:, badge_id:, palette_id:, ... }, ... ]
#   Badger.colorway(3)                  # => { ..., rules:, colors: }
require "badger"
require "badger/engine"
require "badger/seeds"
require "badger/editor"
require "badger/compositions"
