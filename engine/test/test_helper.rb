# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Nothing in the suite is allowed out to the network; the sidecar is a
# subprocess, not a request.
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # The sidecar is a process per shaping call; parallel workers would only
    # contend for the same handful of cores.
    parallelize(workers: 1)

    FONT = "badger-test".freeze

    def badge_document(name: "Stockholm", text: "HOH HIH")
      {
        "name" => name,
        "shape" => { "kind" => "ellipse", "rx" => 260, "ry" => 170 },
        "regions" => [
          { "kind" => "rule", "distance" => 0, "weight" => 5 },
          { "kind" => "band", "name" => "ring", "outer" => -8, "width" => 40 },
          { "kind" => "interior", "name" => "field", "inside" => -52 }
        ],
        "type" => [
          { "mode" => "follow", "text" => text, "font" => FONT, "region" => "ring", "inset" => 7, "sweep" => "top", "align" => "justify" },
          { "mode" => "fit", "text" => "H", "font" => FONT, "region" => "field", "fit" => "chord_at_x", "at" => 0, "inset" => 30 }
        ]
      }
    end

    def create_badge(name: "Stockholm", **options)
      Badger::Badge.create!(name: name, spec: badge_document(name: name, **options))
    end

    # Pandatone somewhere else, configured and answering over HTTP, stubbed
    # at the wire.
    def with_pandatone(palettes: {}, url: "https://pandatone.test", token: "sekrit")
      stub_request(:get, "#{url}/api/v1/palettes")
        .to_return(body: palettes.keys.map { |id, name| { id: id, name: name, tags: [] } }.to_json,
          headers: { "Content-Type" => "application/json" })
      palettes.each { |(id, name), hexes| stub_palette(url, id, name, hexes) }

      was = [ Pandatone::Dresser.url, Pandatone::Dresser.token, Pandatone::Dresser.source ]
      Pandatone::Dresser.url = url
      Pandatone::Dresser.token = token
      Pandatone::Dresser.source = -> { Pandatone::Dresser::Client.configured.palettes_json }
      Pandatone::Dresser::Catalog.forget!

      yield
    ensure
      Pandatone::Dresser.url, Pandatone::Dresser.token, Pandatone::Dresser.source = was
      Pandatone::Dresser::Catalog.forget!
    end

    def stub_palette(url, id, name, hexes)
      colors = hexes.each_with_index.map do |hex, index|
        { id: (id * 100) + index, name: "#{name.parameterize}-#{index}", hex: hex,
          rgb: { r: hex[1..2].to_i(16), g: hex[3..4].to_i(16), b: hex[5..6].to_i(16) }, tags: [] }
      end
      stub_request(:get, "#{url}/api/v1/palettes/#{id}")
        .to_return(body: { id: id, name: name, tags: [], colors: colors }.to_json,
          headers: { "Content-Type" => "application/json" })
    end

    def pandatone_palette(*hexes, id: 7, name: "Sample")
      colors = hexes.each_with_index.map do |hex, index|
        Pandatone::Dresser::Color.new(id: (id * 100) + index, name: "Colour #{index}", hex: hex,
          red: hex[1..2].to_i(16), green: hex[3..4].to_i(16), blue: hex[5..6].to_i(16))
      end
      Pandatone::Dresser::Palette.new(id: id, name: name, colors: colors)
    end
  end
end

class ActionDispatch::IntegrationTest
  include Badger::Engine.routes.url_helpers

  setup do
    sign_in_as
    sign_in_client
  end

  def sign_in_as(_user = nil) = cookies[:signed_in] = "yes"
  def sign_out = cookies.delete("signed_in")
  def sign_in_client(_user = nil) = @api_token = Dummy::API_TOKEN
  def sign_out_client = @api_token = nil
  def json = JSON.parse(response.body)

  %w[ get post patch put delete ].each do |verb|
    define_method(verb) do |path, **options|
      if @api_token
        options[:headers] = { "Authorization" => "Bearer #{@api_token}" }.merge(options[:headers] || {})
      end
      super(path, **options)
    end
  end
end
