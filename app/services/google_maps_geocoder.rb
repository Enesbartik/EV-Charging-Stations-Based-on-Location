require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

class GoogleMapsGeocoder
  class Error < StandardError; end

  API_URL = "https://maps.googleapis.com/maps/api/geocode/json"

  def initialize(query:, http_adapter: Net::HTTP, api_key: nil)
    @query = query.to_s.strip
    @http_adapter = http_adapter
    @provided_api_key = api_key
  end

  def call
    return [] if @query.empty?

    uri = build_uri

    response = @http_adapter.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: 10,
      read_timeout: 20
    ) do |http|
      http.get(uri.request_uri)
    end

    unless response.code.to_i.between?(200, 299)
      raise Error, "Google Maps HTTP #{response.code} hatası döndürdü."
    end

    payload = JSON.parse(response.body)
    status = payload["status"]

    case status
    when "OK"
      payload["results"] || []
    when "ZERO_RESULTS"
      []
    when "REQUEST_DENIED"
      raise Error, payload["error_message"] || "Google Maps isteği reddedildi."
    else
      raise Error, payload["error_message"] || "Google Maps sorgusu başarısız oldu."
    end
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
      address: @query,
      key: api_key
    )
    uri
  end

  def api_key
  @provided_api_key.presence ||
    ENV["GOOGLE_MAPS_SERVER_API_KEY"].presence ||
    Rails.application.credentials.google_maps_server_api_key.presence ||
    raise(Error, "Google Maps Geocoding API anahtarı bulunamadı.")
end
end
