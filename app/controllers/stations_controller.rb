class StationsController < ApplicationController
  before_action :set_station,
                only: %i[edit update destroy toggle_favorite]

def index
  @stations = Station.order(
    favorite: :desc,
    updated_at: :desc
  )

  respond_to do |format|
    format.html

    format.json do
      manual_stations = @stations.where(source: "manual")

      render json: manual_stations.map { |station|
        {
          id: station.id,
          name: station.name,
          address: station.address,
          latitude: station.latitude.to_f,
          longitude: station.longitude.to_f,
          favorite: station.favorite?
        }
      }
    end
  end
end

  def new
    @station = Station.new
  end

  def create
    @station = build_station
    was_new_record = @station.new_record?

    if @station.save
      respond_to do |format|
        format.html do
          redirect_to stations_path,
                      notice: "İstasyon listeye kaydedildi.",
                      status: :see_other
        end

        format.json do
          render json: {
            message: "İstasyon listeye kaydedildi.",
            station: @station
          }, status: was_new_record ? :created : :ok
        end
      end
    else
      respond_to do |format|
        format.html do
          render :new,
                 status: :unprocessable_entity
        end

        format.json do
          render json: {
            errors: @station.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
  end

  def update
    if @station.update(editable_station_params)
      redirect_to stations_path,
                  notice: "İstasyon güncellendi.",
                  status: :see_other
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  def toggle_favorite
    @station.update!(
      favorite: !@station.favorite?
    )

    message =
      if @station.favorite?
        "İstasyon favorilere eklendi."
      else
        "İstasyon favorilerden çıkarıldı."
      end

    redirect_to stations_path,
                notice: message,
                status: :see_other
  end

  def destroy
    @station.destroy!

    redirect_to stations_path,
                notice: "İstasyon listeden silindi.",
                status: :see_other
  end

  private

  def set_station
    @station = Station.find(params[:id])
  end

  def build_station
    attributes = station_params.to_h

    station =
      if attributes["external_id"].present?
        Station.find_or_initialize_by(
          external_id: attributes["external_id"]
        )
      else
        Station.new
      end

    station.assign_attributes(attributes)

    station.source =
      if attributes["external_id"].present?
        "open_charge_map"
      else
        "manual"
      end

    station
  end

  def station_params
    params.require(:station).permit(
      :external_id,
      :name,
      :address,
      :latitude,
      :longitude
    )
  end

  def editable_station_params
    params.require(:station).permit(
      :name,
      :address,
      :latitude,
      :longitude
    )
  end
end