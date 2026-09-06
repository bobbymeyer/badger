# frozen_string_literal: true

module Badger
  module Geometry
    # Parses an SVG path `d` attribute into a Path. Supports every command
    # in the SVG 1.1 grammar, absolute and relative. Quadratics are elevated
    # to cubics; arcs are converted to cubics of at most a quarter turn each
    # (the standard center-parameterization from the SVG spec, appendix F.6).
    class SvgPathParser
      class ParseError < Badger::Error; end

      TOKEN = /[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/
      COMMAND = /\A[A-Za-z]\z/

      def initialize(d)
        @tokens = d.scan(TOKEN)
        @pos = 0
      end

      def path
        subpaths = []
        segments = []
        current = start = Point.new(0.0, 0.0)
        cubic_control = quad_control = nil
        command = nil

        until @pos >= @tokens.size
          if COMMAND.match?(@tokens[@pos])
            command = @tokens[@pos]
            @pos += 1
          elsif command.nil?
            raise ParseError, "path data must begin with a command, got #{@tokens[@pos].inspect}"
          end

          next_cubic_control = next_quad_control = nil

          case command
          when "M", "m"
            subpaths << Path::Subpath.new(segments: segments, closed: false) unless segments.empty?
            segments = []
            p = read_point(command == "m" ? current : nil)
            current = start = p
            command = command == "m" ? "l" : "L"
          when "L", "l"
            p = read_point(command == "l" ? current : nil)
            segments << Line.new(current, p)
            current = p
          when "H", "h"
            x = read_number
            p = Point.new(command == "h" ? current.x + x : x, current.y)
            segments << Line.new(current, p)
            current = p
          when "V", "v"
            y = read_number
            p = Point.new(current.x, command == "v" ? current.y + y : y)
            segments << Line.new(current, p)
            current = p
          when "C", "c"
            rel = command == "c" ? current : nil
            c1 = read_point(rel)
            c2 = read_point(rel)
            p = read_point(rel)
            segments << Cubic.new(current, c1, c2, p)
            next_cubic_control = c2
            current = p
          when "S", "s"
            rel = command == "s" ? current : nil
            c1 = cubic_control ? current * 2 - cubic_control : current
            c2 = read_point(rel)
            p = read_point(rel)
            segments << Cubic.new(current, c1, c2, p)
            next_cubic_control = c2
            current = p
          when "Q", "q"
            rel = command == "q" ? current : nil
            c = read_point(rel)
            p = read_point(rel)
            segments << Cubic.from_quadratic(current, c, p)
            next_quad_control = c
            current = p
          when "T", "t"
            c = quad_control ? current * 2 - quad_control : current
            p = read_point(command == "t" ? current : nil)
            segments << Cubic.from_quadratic(current, c, p)
            next_quad_control = c
            current = p
          when "A", "a"
            rx = read_number
            ry = read_number
            rotation = read_number * Math::PI / 180.0
            large_arc = read_flag
            sweep = read_flag
            p = read_point(command == "a" ? current : nil)
            segments.concat(arc_to_cubics(current, rx, ry, rotation, large_arc, sweep, p))
            current = p
          when "Z", "z"
            segments << Line.new(current, start) unless current.approx?(start)
            subpaths << Path::Subpath.new(segments: segments, closed: true) unless segments.empty?
            segments = []
            current = start
            command = nil
          end

          cubic_control = next_cubic_control
          quad_control = next_quad_control
        end

        subpaths << Path::Subpath.new(segments: segments, closed: false) unless segments.empty?
        Path.new(subpaths)
      end

      private

      def read_number
        token = @tokens[@pos]
        raise ParseError, "expected a number, got #{token.inspect}" if token.nil? || COMMAND.match?(token)

        @pos += 1
        Float(token)
      end

      # Arc flags may be written without separators ("0 1 1" or "011"); the
      # tokenizer yields them as numbers, so a digit string of length > 1
      # here means the flags were run together with what follows.
      def read_flag
        token = @tokens[@pos]
        raise ParseError, "expected an arc flag, got #{token.inspect}" if token.nil? || COMMAND.match?(token)

        if token.length > 1 && token.match?(/\A[01]/)
          @tokens[@pos] = token[1..]
          token = token[0]
        else
          @pos += 1
        end
        raise ParseError, "arc flag must be 0 or 1, got #{token.inspect}" unless %w[0 1].include?(token)

        token == "1"
      end

      def read_point(relative_to)
        p = Point.new(read_number, read_number)
        relative_to ? relative_to + p : p
      end

      def arc_to_cubics(from, rx, ry, phi, large_arc, sweep, to)
        return [] if from.approx?(to)
        return [Line.new(from, to)] if rx.zero? || ry.zero?

        rx = rx.abs
        ry = ry.abs
        cos_phi = Math.cos(phi)
        sin_phi = Math.sin(phi)

        dx = (from.x - to.x) / 2.0
        dy = (from.y - to.y) / 2.0
        x1p = cos_phi * dx + sin_phi * dy
        y1p = -sin_phi * dx + cos_phi * dy

        lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1
          rx *= Math.sqrt(lambda)
          ry *= Math.sqrt(lambda)
        end

        numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        coefficient = Math.sqrt([numerator / denominator, 0.0].max) * (large_arc == sweep ? -1 : 1)
        cxp = coefficient * rx * y1p / ry
        cyp = coefficient * -ry * x1p / rx

        center = Point.new(cos_phi * cxp - sin_phi * cyp + (from.x + to.x) / 2.0,
                           sin_phi * cxp + cos_phi * cyp + (from.y + to.y) / 2.0)

        u = Point.new((x1p - cxp) / rx, (y1p - cyp) / ry)
        v = Point.new((-x1p - cxp) / rx, (-y1p - cyp) / ry)
        theta1 = vector_angle(Point.new(1.0, 0.0), u)
        delta = vector_angle(u, v)
        delta -= TAU if !sweep && delta.positive?
        delta += TAU if sweep && delta.negative?

        segments = (delta.abs / (Math::PI / 2)).ceil
        step = delta / segments
        Array.new(segments) do |i|
          a0 = theta1 + i * step
          a1 = a0 + step
          alpha = 4.0 / 3 * Math.tan((a1 - a0) / 4)
          local = [
            Point.new(Math.cos(a0), Math.sin(a0)),
            Point.new(Math.cos(a0) - alpha * Math.sin(a0), Math.sin(a0) + alpha * Math.cos(a0)),
            Point.new(Math.cos(a1) + alpha * Math.sin(a1), Math.sin(a1) - alpha * Math.cos(a1)),
            Point.new(Math.cos(a1), Math.sin(a1))
          ]
          world = local.map { |p| center + Point.new(p.x * rx, p.y * ry).rotate(phi) }
          world[0] = i.zero? ? from : world[0]
          world[3] = i == segments - 1 ? to : world[3]
          Cubic.new(*world)
        end
      end

      def vector_angle(u, v)
        cosine = (u.dot(v) / (u.length * v.length)).clamp(-1.0, 1.0)
        angle = Math.acos(cosine)
        u.cross(v).negative? ? -angle : angle
      end
    end
  end
end
