require "test_helper"

class StationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @station = Station.create!(
      name: "Test Station",
      address: "Ankara",
      latitude: 39.9208,
      longitude: 32.8541,
      favorite: false,
      source: "manual"
    )
  end

  test "shows saved stations" do
    get stations_url

    assert_response :success
  end

  test "creates a manual station" do
    assert_difference("Station.count", 1) do
      post stations_url, params: {
        station: {
          name: "New Station",
          address: "Balgat",
          latitude: 39.9100,
          longitude: 32.8200
        }
      }
    end

    station = Station.order(:created_at).last

    assert_redirected_to stations_url
    assert_equal "New Station", station.name
    assert_equal "manual", station.source
  end

  test "updates station name and location" do
    patch station_url(@station), params: {
      station: {
        name: "Updated Station",
        address: "Çankaya",
        latitude: 39.9000,
        longitude: 32.8000
      }
    }

    @station.reload

    assert_redirected_to stations_url
    assert_equal "Updated Station", @station.name
    assert_equal 39.9, @station.latitude.to_f
    assert_equal 32.8, @station.longitude.to_f
  end

  test "toggles station favourite" do
    assert_not @station.favorite?

    patch toggle_favorite_station_url(@station)

    assert_redirected_to stations_url
    assert @station.reload.favorite?
  end

  test "deletes station" do
    assert_difference("Station.count", -1) do
      delete station_url(@station)
    end

    assert_redirected_to stations_url
  end


  test "returns manual stations as json" do
    get stations_url(format: :json)

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal @station.name, body.first["name"]
    assert_equal @station.latitude.to_f, body.first["latitude"]
    assert_equal false, body.first["favorite"]
  end
end