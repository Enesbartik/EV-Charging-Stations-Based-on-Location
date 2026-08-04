class ChargingStationsController < ApplicationController
  ALLOWED_DISTANCES = [5, 10].freeze

  def index
    latitude = Float(params.require(:latitude))
    longitude = Float(params.require(:longitude))
    distance = Integer(params.fetch(:distance, 10))

    unless ALLOWED_DISTANCES.include?(distance)
      render json: {
        error: "Arama mesafesi 5 veya 10 km olmalıdır."
      }, status: :unprocessable_entity

      return
    end

    stations = OpenChargeMapClient.new(
      latitude: latitude,
      longitude: longitude,
      distance: distance
    ).call

    render json: stations.filter_map { |station| format_station(station) }
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