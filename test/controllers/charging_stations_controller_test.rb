require "test_helper"

class ChargingStationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @favorite_station = Station.create!(
      name: "Favorite Station",
      address: "Ankara",
      latitude: 39.9208,
      longitude: 32.8541,
      favorite: true,
      source: "open_charge_map",
      external_id: "42"
    )
  end

  def with_open_charge_map_response(fake_response)
    original_call = OpenChargeMapClient.instance_method(:call)

    OpenChargeMapClient.define_method(:call) do
      fake_response
    end

    yield
  ensure
    OpenChargeMapClient.define_method(:call, original_call)
  end

  test "rejects missing coordinates" do
    get charging_stations_path,
        params: { latitude: "41.0" },
        as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)

    assert_equal(
      "Geçerli latitude ve longitude değerleri gönderilmelidir.",
      body["error"]
    )
  end

  test "accepts valid distance values" do
    fake_response = [
      {
        "ID" => 1,
        "AddressInfo" => {
          "Title" => "Test",
          "Latitude" => 41.0,
          "Longitude" => 29.0
        },
        "Connections" => []
      }
    ]

    allowed_distances = [
      1, 2, 5, 10, 15, 20,
      25, 30
    ]

    with_open_charge_map_response(fake_response) do
      allowed_distances.each do |distance|
        get charging_stations_path,
            params: {
              latitude: "41.0",
              longitude: "29.0",
              distance: distance
            },
            as: :json

        assert_response(
          :success,
          "#{distance} km kabul edilmeliydi"
        )
      end
    end
  end

  test "rejects invalid distance value strings with unprocessable entity" do
    get charging_stations_path,
        params: {
          latitude: "41.0",
          longitude: "29.0",
          distance: "abc"
        },
        as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)

    assert_equal(
      "Geçerli latitude ve longitude değerleri gönderilmelidir.",
      body["error"]
    )
  end

  test "rejects invalid distance values with unprocessable entity" do
    get charging_stations_path,
        params: {
          latitude: "41.0",
          longitude: "29.0",
          distance: "12"
        },
        as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)

    assert_equal(
      "Arama mesafesi 1, 2, 5, 10, 15, 20, 25 veya 30 km olmalıdır.",
      body["error"]
    )
  end

  test "returns favorite metadata for open charge map stations" do
    fake_response = [
      {
        "ID" => 42,
        "ExternalId" => "42",
        "AddressInfo" => {
          "Title" => "Open Map Station",
          "AddressLine1" => "Ankara",
          "Town" => "Çankaya",
          "Latitude" => 39.9208,
          "Longitude" => 32.8541
        },
        "Connections" => [],
        "OperatorInfo" => {
          "Title" => "Operator"
        },
        "StatusType" => {
          "Title" => "Operational"
        }
      },
      {
        "ID" => 43,
        "ExternalId" => "43",
        "AddressInfo" => {
          "Title" => "Open Map Station 2",
          "AddressLine1" => "Ankara",
          "Town" => "Mamak",
          "Latitude" => 39.9,
          "Longitude" => 32.9
        },
        "Connections" => [],
        "OperatorInfo" => {
          "Title" => "Operator"
        },
        "StatusType" => {
          "Title" => "Operational"
        }
      }
    ]

    with_open_charge_map_response(fake_response) do
      get charging_stations_path,
          params: {
            latitude: "41.0",
            longitude: "29.0",
            distance: "10"
          },
          as: :json
    end

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal true, body.first["favorite"]
    assert_equal false, body.second["favorite"]
  end
end