# frozen_string_literal: true

module Badger
  # Fit: scale a shaped run to a region measure. Three policies:
  #
  #   :fill     scale to the measure - uniformly by width or height, or on
  #             both axes with a range-constrained stretch
  #   :contain  scale up to the measure, capped at max_size
  #   :fixed    keep the size; the region only positions
  #
  # Measurement is on ink bounds, never font metrics, except for the band
  # fit, where cap height equals the band width by definition.
  class Fit
    POLICIES = %i[fill contain fixed].freeze
    AXES = %i[width height both].freeze

    Result = Data.define(:run, :scale_x, :scale_y) do
      def stretch = scale_y / scale_x
      def size = run.size
    end

    attr_reader :policy, :axes, :max_size, :stretch

    # stretch: allowed range of scale_y / scale_x when axes: :both. Required
    # there, refused elsewhere: non-uniform scaling is never a silent default.
    def initialize(policy: :fill, axes: :width, max_size: nil, stretch: nil)
      raise ArgumentError, "policy must be one of #{POLICIES.join(', ')}" unless POLICIES.include?(policy)
      raise ArgumentError, "axes must be one of #{AXES.join(', ')}" unless AXES.include?(axes)
      raise ArgumentError, "axes: :both needs a stretch: range" if axes == :both && !stretch.is_a?(Range)
      raise ArgumentError, "stretch: only applies to axes: :both" if stretch && axes != :both
      raise ArgumentError, "policy :contain needs max_size:" if policy == :contain && max_size.nil?

      @policy = policy
      @axes = axes
      @max_size = max_size&.to_f
      @stretch = stretch
    end

    # Scale `run` to a box. Either dimension may be nil when the axis is
    # not measured. Returns a Result whose run is uniformly scaled by
    # scale_x; scale_y differs only under axes: :both.
    def to_box(run, width: nil, height: nil)
      return Result.new(run: run, scale_x: 1.0, scale_y: 1.0) if policy == :fixed
      if axes == :both && run.respond_to?(:uniform_only?) && run.uniform_only?
        raise ArgumentError, "illustration scales uniformly only; use axes: :width or :height"
      end

      ink_w = run.ink_width
      ink_h = run.ink_height
      raise Badger::Error, "cannot fit a run with no ink" if ink_w.nil? || ink_w <= 0 || ink_h <= 0

      kx = width && width / ink_w
      ky = height && height / ink_h

      case policy
      when :fill then fill(run, kx, ky)
      when :contain then contain(run, kx, ky)
      end
    end

    # Cap height equals the band width less an inset on each edge.
    def to_band(run, band, inset: 0.0)
      raise Badger::Error, "the run's font has no cap height" unless run.cap_height

      target = band.width - 2 * inset
      raise ArgumentError, "inset leaves no room in the band" unless target.positive?
      return Result.new(run: run, scale_x: 1.0, scale_y: 1.0) if policy == :fixed

      k = target / run.cap_height
      k = [k, max_size / run.size].min if policy == :contain
      Result.new(run: run.scale_by(k), scale_x: k, scale_y: k)
    end

    # A line scaled to the interior's horizontal chord at height y and
    # centred on it. `anchor` says what y is: the ink's vertical centre or
    # the baseline. `edge: :narrowest` uses the tightest chord across the
    # ink's height instead of the chord through its centre, so the line
    # fits inside a convex region.
    def to_chord_at_y(run, interior, y, inset: 0.0, anchor: :center, edge: :center, through: nil)
      chord_fit(run, interior, y, inset, anchor, edge, through, :horizontal)
    end

    # A glyph or line scaled to the interior's vertical chord at x.
    def to_chord_at_x(run, interior, x, inset: 0.0, anchor: :center, edge: :center, through: nil)
      chord_fit(run, interior, x, inset, anchor, edge, through, :vertical)
    end

    private

    def fill(run, kx, ky)
      case axes
      when :width
        raise ArgumentError, "axes: :width needs width:" unless kx

        Result.new(run: run.scale_by(kx), scale_x: kx, scale_y: kx)
      when :height
        raise ArgumentError, "axes: :height needs height:" unless ky

        Result.new(run: run.scale_by(ky), scale_x: ky, scale_y: ky)
      when :both
        raise ArgumentError, "axes: :both needs width: and height:" unless kx && ky

        ratio = (ky / kx).clamp(stretch.begin, stretch.end)
        Result.new(run: run.scale_by(kx), scale_x: kx, scale_y: kx * ratio)
      end
    end

    def contain(run, kx, ky)
      # the size cap is a type notion; artwork has no em to cap
      cap = run.respond_to?(:size) ? max_size / run.size : nil
      candidates = [kx, ky, cap].compact
      candidates = [kx, cap].compact if axes == :width && kx
      candidates = [ky, cap].compact if axes == :height && ky
      k = candidates.min
      Result.new(run: run.scale_by(k), scale_x: k, scale_y: k)
    end

    # The chord depends on where the ink sits and where the ink sits depends
    # on the scale, so the fit is a root of
    #   h(k) = available chord at scale k - k * unscaled ink extent
    # which is monotone on a convex region. Bracket and bisect; placed ink
    # bounds are affine in k, so nothing is re-flattened per step.
    def chord_fit(run, interior, position, inset, anchor, edge, through, direction)
      raise ArgumentError, "anchor must be :center or :baseline" unless %i[center baseline].include?(anchor)
      raise ArgumentError, "edge must be :center or :narrowest" unless %i[center narrowest].include?(edge)

      base = run.ink_bounds
      raise Badger::Error, "cannot fit a run with no ink" unless base

      horizontal = direction == :horizontal
      ink0 = horizontal ? base[1].x - base[0].x : base[1].y - base[0].y
      raise Badger::Error, "cannot fit a run with no ink" unless ink0.positive?

      chord_for = lambda do |k|
        lo, hi = placed_across_range(base, k, position, anchor, horizontal)
        levels = if edge == :narrowest then [lo, hi]
                 elsif anchor == :baseline then [(lo + hi) / 2]
                 else [position]
                 end
        chords = levels.map { |level| horizontal ? interior.chord_at_y(level, through: through) : interior.chord_at_x(level, through: through) }
        next nil if chords.any?(&:nil?)

        a = chords.map(&:first).max + inset
        b = chords.map(&:last).min - inset
        b > a ? [a, b] : nil
      end

      k = case policy
          when :fixed then 1.0
          when :fill then solve(chord_for, ink0, position, horizontal)
          when :contain then [solve(chord_for, ink0, position, horizontal), max_size / run.size].min
          end

      chord = chord_for.call(k)
      raise Badger::Error, "no chord of the interior at #{horizontal ? 'y' : 'x'} = #{position}" unless chord

      scaled = run.scale_by(k)
      min, max = base.map { |p| p * k }
      center = (min + max) / 2
      along = (chord[0] + chord[1]) / 2
      dx, dy = if horizontal
                 [along - center.x, anchor == :baseline ? position : position - center.y]
               else
                 [position - center.x, along - center.y]
               end
      Setting.new(scaled, Geometry::Affine.translate(dx, dy))
    end

    # The placed ink's extent across the chord direction at scale k.
    def placed_across_range(base, k, position, anchor, horizontal)
      if horizontal
        lo = base[0].y * k
        hi = base[1].y * k
        shift = anchor == :baseline ? position : position - (lo + hi) / 2
      else
        lo = base[0].x * k
        hi = base[1].x * k
        shift = position - (lo + hi) / 2
      end
      [lo + shift, hi + shift]
    end

    def solve(chord_for, ink0, position, horizontal)
      h = lambda do |k|
        chord = chord_for.call(k)
        chord ? chord[1] - chord[0] - k * ink0 : -Float::INFINITY
      end
      first = chord_for.call(0.0)
      raise Badger::Error, "no chord of the interior at #{horizontal ? 'y' : 'x'} = #{position}" unless first

      lo = 0.0
      hi = (first[1] - first[0]) / ink0
      return hi if h.call(hi).abs < 1e-12

      hi *= 2 while h.call(hi).positive? && hi < 1e6
      60.times do
        mid = (lo + hi) / 2
        h.call(mid).positive? ? lo = mid : hi = mid
      end
      (lo + hi) / 2
    end
  end
end
