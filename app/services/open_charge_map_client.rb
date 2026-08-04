require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

class OpenChargeMapClient
  class Error < StandardError; end

  API_URL = "https://api.openchargemap.io/v3/poi/"

  def initialize(
  latitude:,
  longitude:,
  distance: 10,
  http_adapter: Net::HTTP,
  api_key: nil
)
  @latitude = Float(latitude)
  @longitude = Float(longitude)
  @distance = Integer(distance)
  @http_adapter = http_adapter
  @provided_api_key = api_key
end

  def call
    uri = build_uri

    response = @http_adapter.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: 10,
      read_timeout: 20
    ) do |http|
      http.get(uri.request_uri, request_headers)
    end

    unless response.code.to_i.between?(200, 299)
      raise Error, "Open Charge Map HTTP #{response.code} hatası döndürdü."
    end

    JSON.parse(response.body)
  rescue Error
    raise
  rescue JSON::ParserError,
         Timeout::Error,
         SocketError,
         SystemCallError,
         OpenSSL::SSL::SSLError => e
    raise Error, e.message
  end

  private

  def build_uri
    uri = URI(API_URL)

    uri.query = URI.encode_www_form(
      output: "json",
      latitude: @latitude,
      longitude: @longitude,
      distance: @distance,
      distanceunit: "KM",
      maxresults: 50,
      compact: true,
      verbose: false,
      key: api_key
    )

    uri
  end

  def request_headers
    {
      "Accept" => "application/json",
      "User-Agent" => "EVChargingMap"
    }
  end

  def api_key
    @provided_api_key ||
      Rails.application.credentials.open_charge_map_api_key ||
      ENV["OPEN_CHARGE_MAP_API_KEY"] ||
      raise(Error, "Open Charge Map API anahtarı bulunamadı.")
  end
end
