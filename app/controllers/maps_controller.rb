class MapsController < ApplicationController
  def index
  end

  def geocode
    query = params.require(:query)

    results = GoogleMapsGeocoder.new(query: query).call

    render json: {
      results: results.map do |result|
        {
          formatted_address: result["formatted_address"],
          latitude: result.dig("geometry", "location", "lat"),
          longitude: result.dig("geometry", "location", "lng"),
          name: result["name"]
        }
      end
    }
  rescue ActionController::ParameterMissing
    render json: {
      error: "Adres sorgusu için query alanı zorunludur."
    }, status: :unprocessable_entity
  rescue GoogleMapsGeocoder::Error => e
    render json: {
      error: e.message
    }, status: :bad_gateway
  end
end
