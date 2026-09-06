# frozen_string_literal: true

module Badger
  # Path booleans and offsets, on skia-pathops through the sidecar. Every
  # method takes Geometry::Paths (or anything with to_d) and returns one
  # Geometry::Path, wound consistently: outer contours one way, holes the
  # other, so the result fills correctly under either fill rule.
  module Booleans
    module_function

    def union(*paths) = run(:union, subject: paths.flatten)
    def difference(subject, *clip) = run(:difference, subject: [subject].flatten, clip: clip.flatten)
    def intersection(subject, *clip) = run(:intersection, subject: [subject].flatten, clip: clip.flatten)
    def xor(subject, *clip) = run(:xor, subject: [subject].flatten, clip: clip.flatten)

    # The union of `paths` grown (positive) or shrunk (negative) by
    # `distance`, with round joins by default.
    def expand(paths, distance, join: :round)
      run(:expand, subject: [paths].flatten, distance: distance.to_f, join: join.to_s)
    end

    def run(operation, subject:, clip: [], **options)
      response = Badger.sidecar.pathops(operation: operation, subject: subject.map(&:to_d), clip: clip.map(&:to_d), **options)
      d = response["path"].to_s
      d.strip.empty? ? Geometry::Path.new([]) : Geometry::Path.parse(d)
    end
  end
end
