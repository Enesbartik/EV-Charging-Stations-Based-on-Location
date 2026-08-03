require "net/http"
require "json"

class OpenChargeMapClient
  class Error < StandardError; end

  API_URL = "https://api.openchargemap.io/v3/poi/"

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  def call
    uri = URI(API_URL)

    uri.query = URI.encode_www_form(
      output: "json",
      latitude: @latitude,
      longitude: @longitude,
      distance: 10,
      distanceunit: "KM",
      maxresults: 50,
      compact: true,
      verbose: false,
      key: api_key
    )

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: 5,
      read_timeout: 10
    ) do |http|
      http.get(uri.request_uri, {
        "Accept" => "application/json",
        "User-Agent" => "EVChargingMap"
      })
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Open Charge Map isteği başarısız oldu."
    end

    JSON.parse(response.body)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout,
         SocketError => e
    raise Error, e.message
  end

  private

  def api_key
    Rails.application.credentials.open_charge_map_api_key ||
      ENV["OPEN_CHARGE_MAP_API_KEY"] ||
      raise(Error, "Open Charge Map API anahtarı bulunamadı.")
  end
end