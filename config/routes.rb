Rails.application.routes.draw do
  root "maps#index"

  get "/charging_stations",
      to: "charging_stations#index",
      as: :charging_stations

  get "/maps/geocode",
      to: "maps#geocode",
      as: :maps_geocode

  resources :stations, except: :show do
    patch :toggle_favorite, on: :member
  end
end