class ChargingStationsController < ApplicationController
  def index
    latitude = Float(params.require(:latitude))
    longitude = Float(params.require(:longitude))

    results = OpenChargeMapClient.new(
      latitude: latitude,
      longitude: longitude
    ).call

    render json: results.filter_map { |station| format_station(station) }
  rescue ActionController::ParameterMissing, ArgumentError
    render json: {
      error: "Geçerli latitude ve longitude değerleri gönderilmelidir."
    }, status: :unprocessable_entity
  rescue OpenChargeMapClient::Error => e
    render json: {
      error: e.message
    }, status: :bad_gateway
  end

  private

  def format_station(station)
    address = station["AddressInfo"] || {}
    latitude = address["Latitude"]
    longitude = address["Longitude"]

    return if latitude.blank? || longitude.blank?

    connections = Array(station["Connections"])

    {
      id: station["ID"],
      name: address["Title"].presence || "Şarj istasyonu",
      address: [
        address["AddressLine1"],
        address["Town"]
      ].compact_blank.join(", "),
      latitude: latitude,
      longitude: longitude,
      operator: station.dig("OperatorInfo", "Title"),
      status: station.dig("StatusType", "Title"),
      power_kw: connections.filter_map { |connection|
        connection["PowerKW"]
      }.max,
      connection_types: connections.filter_map { |connection|
        connection.dig("ConnectionType", "Title")
      }.uniq
    }
  end
end