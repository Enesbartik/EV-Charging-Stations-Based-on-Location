require "test_helper"

class StationTest < ActiveSupport::TestCase
  test "valid station can be saved" do
    station = Station.new(
      name: "Test Station",
      latitude: 39.9208,
      longitude: 32.8541
    )

    assert station.valid?
  end

  test "name is required" do
    station = Station.new(
      latitude: 39.9208,
      longitude: 32.8541
    )

    assert_not station.valid?
    assert_includes station.errors[:name], "can't be blank"
  end

  test "latitude must be within valid range" do
    station = Station.new(
      name: "Test Station",
      latitude: 100,
      longitude: 32.8541
    )

    assert_not station.valid?
  end

  test "longitude must be within valid range" do
    station = Station.new(
      name: "Test Station",
      latitude: 39.9208,
      longitude: 200
    )

    assert_not station.valid?
  end
end