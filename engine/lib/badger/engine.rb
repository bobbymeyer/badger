require "rails/engine"

# What the engine is built on. Required here rather than left to the host's
# Gemfile: a gem's dependencies are resolved by Bundler and loaded by nobody.
require "propshaft"
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"
require "its-swiss"
require "pandatone"

module Badger
  # The host's controllers the engine's inherit from. The host's decide who
  # gets in; the engine never has to know what a user is.
  mattr_accessor :base_controller_class, default: "::ApplicationController"
  mattr_accessor :api_base_controller_class, default: "::ApiController"

  # Directories the badge editor may name fonts from. A badge names a font
  # by its file name without the extension; the host says where to look.
  mattr_accessor :font_directories, default: []

  # A mountable engine: its own controllers, routes, views, migrations and
  # stylesheets, under the Badger namespace and the badger_ table prefix.
  #
  #   mount Badger::Engine, at: "/badger"
  class Engine < ::Rails::Engine
    isolate_namespace Badger

    initializer "badger.mime_types" do
      Mime::Type.register "image/svg+xml", :svg unless Mime[:svg]
    end

    # The engine's migrations run with the host's rather than being copied in.
    initializer "badger.migrations" do |app|
      unless app.root.to_s.start_with?(root.to_s)
        config.paths["db/migrate"].expanded.each do |path|
          app.config.paths["db/migrate"] << path
        end
      end
    end

    # Propshaft finds an engine's app/assets/stylesheets on its own; the
    # JavaScript is not in that default set.
    initializer "badger.assets" do |app|
      app.config.assets.paths << root.join("app/assets/javascripts") if app.config.respond_to?(:assets)
    end

    # Pinned from the engine rather than written into the host's importmap:
    # what the engine ships, the engine pins. The layout imports the module
    # that registers the engine's controllers, so a host adds nothing.
    initializer "badger.importmap", before: "importmap" do |app|
      next unless app.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/assets/javascripts")
    end

    # The host's font directories reach the core's registry once the host's
    # initializers have run.
    config.after_initialize do
      Array(Badger.font_directories).each { |dir| Badger::Fonts.add_directory(dir) if Dir.exist?(dir.to_s) }
    end
  end

  class << self
    def badges
      BadgeSerializer.many(Badge.order(:name))
    end

    # One badge with its document and what rendering it measures, by id or
    # by name, or nil.
    def badge(key)
      badge = Badge.friendly(key)
      BadgeSerializer.one(badge) if badge
    end

    # The badge as SVG: unresolved fills, or dressed in a colorway by id.
    def badge_svg(key, colorway: nil, padding: 0)
      badge = Badge.friendly(key)
      return nil if badge.nil?

      dressing = colorway && badge.colorways.find_by(id: colorway)
      badge.svg(colors: dressing&.fills, padding: padding)
    end

    def colorways
      ColorwaySerializer.many(Colorway.order(:id))
    end

    def colorway(id)
      colorway = Colorway.find_by(id: id)
      ColorwaySerializer.one(colorway) if colorway
    end

    # The API's description of itself, as a Hash ready to serve as JSON.
    def openapi
      @openapi ||= YAML.safe_load_file(Engine.root.join("config/openapi.yml"))
    end
  end
end
