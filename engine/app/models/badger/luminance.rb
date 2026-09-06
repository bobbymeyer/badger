# OKLab's L: how light a colour looks, on a scale where the steps are
# perceptually even. Computed here rather than asked of Pandatone, which
# stores colour and says its own brightness figure is not perceptual.
module Badger
  module Luminance
    module_function

    def of(red, green, blue)
      r, g, b = linearize(red), linearize(green), linearize(blue)

      long   = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
      medium = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
      short  = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

      0.2104542553 * Math.cbrt(long) + 0.7936177850 * Math.cbrt(medium) - 0.0040720468 * Math.cbrt(short)
    end

    def of_hex(hex)
      r, g, b = hex.to_s.delete_prefix("#").scan(/\h\h/).map { |pair| pair.to_i(16) }
      of(r, g, b)
    end

    def linearize(channel)
      c = channel / 255.0
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
  end
end
