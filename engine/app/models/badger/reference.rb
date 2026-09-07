module Badger
  # The photograph a badge is redrawn from, drawn under the badge at a chosen
  # strength. The reference badges were measured off their photographs in the
  # photographs' own pixels, so the default placement is one unit per pixel
  # with the image centred on the badge's origin; the editor moves and
  # scales it from there.
  class Reference < ApplicationRecord
    CONTENT_TYPES = %w[ image/png image/jpeg ].freeze
    MOST_BYTES = 8.megabytes

    belongs_to :badge, inverse_of: :reference

    validates :content_type, inclusion: { in: CONTENT_TYPES, message: "must be a PNG or a JPEG" }
    validates :data, presence: true
    validates :width, :height, numericality: { greater_than: 0 }
    validates :scale, numericality: { greater_than: 0 }
    validates :opacity, numericality: { in: 0..1 }
    validate :data_is_not_too_large

    # Take an uploaded file: its bytes, its type, and its size read from its
    # header, so no image library is needed for the two formats that matter.
    def image=(upload)
      bytes = upload.respond_to?(:read) ? upload.read : upload.to_s
      self.data = bytes
      self.content_type = upload.respond_to?(:content_type) ? upload.content_type.to_s : sniff(bytes)
      self.content_type = sniff(bytes) if sniff(bytes) && content_type != sniff(bytes)
      size = Reference.measure(bytes)
      self.width, self.height = size || [ 0, 0 ]
    end

    # The image's box in badge units: centred on (x, y), scale units a pixel.
    def box
      w = width * scale
      h = height * scale
      { x: x - w / 2, y: y - h / 2, width: w, height: h }
    end

    # [width, height] of a PNG or a JPEG from its header; nil for anything else.
    def self.measure(bytes)
      return nil if bytes.nil? || bytes.bytesize < 10

      if bytes.byteslice(0, 8) == "\x89PNG\r\n\x1A\n".b
        bytes.bytesize >= 24 ? bytes.byteslice(16, 8).unpack("NN") : nil
      elsif bytes.byteslice(0, 2) == "\xFF\xD8".b
        measure_jpeg(bytes)
      end
    end

    def self.measure_jpeg(bytes)
      i = 2
      while i + 9 < bytes.bytesize
        return nil unless bytes.getbyte(i) == 0xFF

        marker = bytes.getbyte(i + 1)
        length = bytes.byteslice(i + 2, 2).unpack1("n")
        # a start-of-frame marker carries the size; C4, C8 and CC are not frames
        if (0xC0..0xCF).cover?(marker) && ![ 0xC4, 0xC8, 0xCC ].include?(marker)
          height, width = bytes.byteslice(i + 5, 4).unpack("nn")
          return [ width, height ]
        end
        i += 2 + length
      end
      nil
    end

    private
      def sniff(bytes)
        return "image/png" if bytes.byteslice(0, 8) == "\x89PNG\r\n\x1A\n".b
        return "image/jpeg" if bytes.byteslice(0, 2) == "\xFF\xD8".b

        nil
      end

      def data_is_not_too_large
        errors.add(:data, "is over #{MOST_BYTES / 1.megabyte} MB") if data && data.bytesize > MOST_BYTES
      end
  end
end
