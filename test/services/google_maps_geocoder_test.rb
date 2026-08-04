require "test_helper"

class GoogleMapsGeocoderTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true)

  class FakeConnection
    attr_reader :captured_uri

    def initialize(response)
      @response = response
    end

    def get(uri, *_headers)
      @captured_uri = uri
      @response
    end
  end

  class FakeHttpAdapter
    attr_reader :captured_connection

    def initialize(response)
      @response = response
    end

    def start(*_arguments, **_options)
      @captured_connection = FakeConnection.new(@response)
      yield @captured_connection
    end
  end

  test "successful geocode response is parsed" do
    response = FakeResponse.new(
      code: "200",
      body: {
        "status" => "OK",
        "results" => [
          {
            "formatted_address" => "Ankara, Türkiye",
            "geometry" => {
              "location" => {
                "lat" => 39.9208,
                "lng" => 32.8541
              }
            }
          }
        ]
      }.to_json
    )

    geocoder = GoogleMapsGeocoder.new(
      query: "Ankara",
      api_key: "test-api-key",
      http_adapter: FakeHttpAdapter.new(response)
    )

    results = geocoder.call

    assert_equal 1, results.length
    assert_equal "Ankara, Türkiye", results.first["formatted_address"]
  end

  test "returns empty results when geocoder gives zero results" do
    response = FakeResponse.new(
      code: "200",
      body: {
        "status" => "ZERO_RESULTS",
        "results" => []
      }.to_json
    )

    geocoder = GoogleMapsGeocoder.new(
      query: "no-such-place",
      api_key: "test-api-key",
      http_adapter: FakeHttpAdapter.new(response)
    )

    assert_equal [], geocoder.call
  end

  test "raises error when geocoder returns unsuccessful http response" do
    response = FakeResponse.new(
      code: "500",
      body: '{"error":"Service unavailable"}'
    )

    geocoder = GoogleMapsGeocoder.new(
      query: "Ankara",
      api_key: "test-api-key",
      http_adapter: FakeHttpAdapter.new(response)
    )

    error = assert_raises(GoogleMapsGeocoder::Error) do
      geocoder.call
    end

    assert_includes error.message, "500"
  end
end
