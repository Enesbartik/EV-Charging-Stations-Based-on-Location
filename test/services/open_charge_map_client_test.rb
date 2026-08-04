require "test_helper"

class OpenChargeMapClientTest < ActiveSupport::TestCase
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

  test "successful API response is parsed" do
    api_data = [
      {
        "ID" => 1,
        "AddressInfo" => {
          "Title" => "Test Charging Station",
          "Latitude" => 41.0,
          "Longitude" => 29.0
        }
      }
    ]

    response = FakeResponse.new(
      code: "200",
      body: api_data.to_json
    )

    client = OpenChargeMapClient.new(
      latitude: 41.0,
      longitude: 29.0,
      distance: 5,
      api_key: "test-api-key",
      http_adapter: FakeHttpAdapter.new(response)
    )

    result = client.call

    assert_equal 1, result.length
    assert_equal(
      "Test Charging Station",
      result.dig(0, "AddressInfo", "Title")
    )
  end

  test "distance value is forwarded to the API query" do
    response = FakeResponse.new(
      code: "200",
      body: [].to_json
    )

    adapter = FakeHttpAdapter.new(response)
    client = OpenChargeMapClient.new(
      latitude: 41.0,
      longitude: 29.0,
      distance: 15,
      api_key: "test-api-key",
      http_adapter: adapter
    )

    client.call

    query = URI.decode_www_form(adapter.captured_connection.captured_uri).to_h
    assert_equal "15", query["distance"]
  end

  test "unsuccessful API response raises client error" do
    response = FakeResponse.new(
      code: "503",
      body: '{"error":"Service unavailable"}'
    )

    client = OpenChargeMapClient.new(
      latitude: 41.0,
      longitude: 29.0,
      distance: 10,
      api_key: "test-api-key",
      http_adapter: FakeHttpAdapter.new(response)
    )

    error = assert_raises(OpenChargeMapClient::Error) do
      client.call
    end

    assert_includes error.message, "503"
  end
end
