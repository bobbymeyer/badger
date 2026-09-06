require "net/http"

# Pandatone's v1 API, which is versioned from its first commit precisely so a
# tool like this one can depend on it.
module Badger
  module Pandatone
    class Client
      PREFIX = "api/v1".freeze
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 15

      def self.configured
        new(url: Badger.pandatone_url, token: Badger.pandatone_token)
      end

      def initialize(url:, token:, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
        raise Pandatone::Error, "no Pandatone url is configured" if url.blank?

        @base = URI.parse(url)
        @token = token
        @open_timeout, @read_timeout = open_timeout, read_timeout
      end

      # Every palette with its colours. Summaries carry no colours and the
      # colours are the whole of what Badger asks about, so each is read
      # in full, once, and the catalogue answers from memory afterwards.
      def palettes_json
        get(PREFIX, "palettes").map { |summary| get(PREFIX, "palettes", summary["id"].to_s) }
      end

      private
        def get(*segments)
          response = fetch(path_for(*segments))

          case response
          when Net::HTTPSuccess then JSON.parse(response.body)
          when Net::HTTPUnauthorized then raise Pandatone::Unauthorized, "#{@base.host} refused the token"
          when Net::HTTPNotFound then raise Pandatone::NotFound, path_for(*segments)
          else raise Pandatone::Error, "#{@base.host} answered #{response.code}"
          end
        end

        def path_for(*segments)
          File.join(@base.path.presence || "/", *segments)
        end

        def fetch(path)
          request = Net::HTTP::Get.new(path)
          request["Authorization"] = "Bearer #{@token}" if @token.present?
          request["Accept"] = "application/json"

          Net::HTTP.start(@base.host, @base.port, use_ssl: @base.scheme == "https",
                          open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
            http.request(request)
          end
        rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
          raise Pandatone::Unreachable, "#{@base.host}: #{e.message}"
        end
    end
  end
end
