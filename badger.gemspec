# frozen_string_literal: true

require_relative "lib/badger/version"

Gem::Specification.new do |spec|
  spec.name = "badger"
  spec.version = Badger::VERSION
  spec.authors = ["Bobby Meyer"]
  spec.summary = "Badge generator: sets type into regions derived from a container path."
  spec.description = "A tree of containers. Each container derives regions. Each region holds type " \
                     "(fitted, followed, or fixed) anchored by locator plus alignment. Returns SVG."
  spec.homepage = "https://github.com/bobbymeyer/badger"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.{rb,py}", "requirements.txt", "README.md", "HANDOFF.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rexml", "~> 3.2"

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rake", "~> 13.0"
end
