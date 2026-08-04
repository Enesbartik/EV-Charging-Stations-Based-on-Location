require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  test "shows charging station map page" do
    get root_url

    assert_response :success
    assert_select "h1", "EV Charging Stations"
    assert_select "[data-controller='map']"
  end
end