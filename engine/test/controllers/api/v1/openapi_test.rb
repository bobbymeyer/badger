require "test_helper"

module Badger
  # The API describes itself, and the description has to be true.
  class Api::V1::OpenapiTest < ActionDispatch::IntegrationTest
    test "serves the description as JSON, to anyone" do
      sign_out_client
      get api_v1_openapi_url

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal "Badger", json.dig("info", "title")
    end

    test "every API route is in the spec, with its verb" do
      routed.each do |path, verb|
        assert spec.dig("paths", path, verb), "#{verb.upcase} #{path} is routed but not described"
      end
    end

    test "every operation in the spec is routed" do
      spec["paths"].each do |path, operations|
        operations.except("parameters").each_key do |verb|
          assert_includes routed, [ path, verb ], "#{verb.upcase} #{path} is described but not routed"
        end
      end
    end

    private
      def spec = @spec ||= Badger.openapi

      def routed
        @routed ||= Badger::Engine.routes.routes.filter_map { |route|
          path = route.path.spec.to_s
          next unless path.start_with?("/api/v1/")

          verb = route.verb.downcase
          next unless %w[get post patch put delete].include?(verb)

          [ path.delete_prefix("/api/v1").sub("(.:format)", "").gsub(/:(\w+)/, '{\1}'), verb ]
        }.uniq
      end
  end
end
