# frozen_string_literal: true

require "json"
require "open3"

module Badger
  # The Python type sidecar: HarfBuzz shaping and fontTools outlines behind a
  # one-request-per-process JSON protocol. The script ships inside the gem;
  # the host only has to provide an interpreter with requirements.txt
  # installed. Set BADGER_PYTHON to pick the interpreter.
  class Sidecar
    class Error < Badger::Error; end
    class Unavailable < Error; end

    SCRIPT = File.expand_path("sidecar/shape.py", __dir__)
    REQUIRED = %w[fonttools uharfbuzz].freeze
    OPTIONAL = %w[skia-pathops].freeze

    attr_reader :python, :timeout

    def initialize(python: ENV.fetch("BADGER_PYTHON", "python3"), timeout: 30)
      @python = python
      @timeout = timeout
    end

    def call(request)
      stdout, stderr, status = Open3.capture3(python, SCRIPT, stdin_data: JSON.generate(request))
      response = parse(stdout, stderr, status)
      raise Error, response["error"] if response.key?("error")

      response
    rescue Errno::ENOENT
      raise Unavailable, "no Python interpreter at #{python.inspect}; set BADGER_PYTHON or install python3"
    end

    def shape(font:, text:, features: {}, variations: {}, direction: nil, script: nil, language: nil)
      call({ op: "shape", font: font, text: text, features: features, variations: variations,
             direction: direction, script: script, language: language }.compact)
    end

    # Reports interpreter and package versions, and whether shaping can run.
    def doctor
      report = call({ op: "doctor" })
      missing = REQUIRED.reject { |package| report[package] }
      report.merge("missing" => missing, "ok" => missing.empty?)
    rescue Unavailable => e
      { "python" => nil, "missing" => REQUIRED, "ok" => false, "error" => e.message }
    end

    private

    def parse(stdout, stderr, status)
      JSON.parse(stdout)
    rescue JSON::ParserError
      detail = stderr.strip.lines.last&.strip || "exit status #{status.exitstatus}"
      raise Error, "sidecar returned no JSON (#{detail})"
    end
  end

  def self.sidecar = (@sidecar ||= Sidecar.new)
  def self.doctor = sidecar.doctor
end
