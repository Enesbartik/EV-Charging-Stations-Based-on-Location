Rails.application.routes.draw do
  root "maps#index"

  get "/charging_stations",
      to: "charging_stations#index",
      as: :charging_stations
end
