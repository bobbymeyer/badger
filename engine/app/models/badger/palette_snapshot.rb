# What the palette held at the moment it was chosen. The snapshot is
# Pandatone's dresser's; the table is this engine's.
module Badger
  class PaletteSnapshot < ApplicationRecord
    include Pandatone::Dresser::Snapshot
  end
end
