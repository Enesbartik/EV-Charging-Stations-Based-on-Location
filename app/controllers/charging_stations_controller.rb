class ChargingStationsController < ApplicationController
  ALLOWED_DISTANCES = [1, 2, 5, 10, 15, 20, 25, 30].freeze

  def index
    latitude = Float(params.require(:latitude))
    longitude = Float(params.require(:longitude))
    distance = Integer(params.fetch(:distance, 10))

    unless ALLOWED_DISTANCES.include?(distance)
      render json: {
        error: "Arama mesafesi 1, 2, 5, 10, 15, 20, 25 veya 30 km olmalıdır."
      }, status: :unprocessable_entity

      return
    end

    stations = OpenChargeMapClient.new(
      latitude: latitude,
      longitude: longitude,
      distance: distance
    ).call

    open_charge_map_ids = stations.filter_map { |station| station["ID"]&.to_s }
    favorite_external_ids = Station.where(
      source: "open_charge_map",
      favorite: true,
      external_id: open_charge_map_ids
    ).pluck(:external_id).map(&:to_s)

    render json: stations.filter_map { |station| format_station(station, favorite_external_ids) }
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

  def format_station(station, favorite_external_ids)
    address = station["AddressInfo"] || {}
    latitude = address["Latitude"]
    longitude = address["Longitude"]
    external_id = station["ID"].to_s

    return if latitude.blank? || longitude.blank?

    connections = Array(station["Connections"])

    {
      id: station["ID"],
      external_id: external_id,
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
      }.uniq,
      favorite: favorite_external_ids.include?(external_id)
    }
  end
end