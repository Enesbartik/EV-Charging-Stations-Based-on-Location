require "test_helper"

class ChargingStationsControllerTest < ActionDispatch::IntegrationTest
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
end
