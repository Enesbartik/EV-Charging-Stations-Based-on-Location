import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "status", "distance"]

  connect() {
    if (!window.L) {
      this.statusTarget.textContent = "Harita kütüphanesi yüklenemedi."
      return
    }

    const istanbul = [41.0082, 28.9784]

    this.map = window.L.map(this.canvasTarget).setView(istanbul, 11)

    window.L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    this.stationLayer = window.L.layerGroup().addTo(this.map)

    this.findUserLocation()
  }

  findUserLocation() {
    if (!navigator.geolocation) {
      this.statusTarget.textContent =
        "Tarayıcınız konum özelliğini desteklemiyor."

      return
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        this.latitude = position.coords.latitude
        this.longitude = position.coords.longitude

        const coordinates = [this.latitude, this.longitude]

        this.map.setView(coordinates, 14)

        this.userMarker = window.L.marker(coordinates, {
          icon: this.createUserIcon()
        })
          .addTo(this.map)
          .bindPopup("Konumunuz")
          .openPopup()

        await this.loadStations()
      },

      () => {
        this.statusTarget.textContent =
          "Konum alınamadı. Tarayıcı konum iznini kontrol edin."
      },

      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 60000
      }
    )
  }

  async changeDistance() {
    if (this.latitude === undefined || this.longitude === undefined) {
      return
    }

    await this.loadStations()
  }

  async loadStations() {
    const distance = this.distanceTarget.value

    this.statusTarget.textContent =
      `${distance} km içindeki şarj istasyonları aranıyor...`

    this.stationLayer.clearLayers()

    const parameters = new URLSearchParams({
      latitude: this.latitude,
      longitude: this.longitude,
      distance: distance
    })

    try {
      const response = await fetch(
        `/charging_stations?${parameters.toString()}`,
        {
          headers: {
            Accept: "application/json"
          }
        }
      )

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "İstasyonlar alınamadı.")
      }

      if (data.length === 0) {
        this.statusTarget.textContent =
          `${distance} km içinde şarj istasyonu bulunamadı.`

        return
      }

      const bounds = window.L.latLngBounds([
        [this.latitude, this.longitude]
      ])

      data.forEach((station) => {
        const marker = this.addStationMarker(station)
        bounds.extend(marker.getLatLng())
      })

      this.map.fitBounds(bounds, {
        padding: [40, 40],
        maxZoom: 15
      })

      this.statusTarget.textContent =
        `${distance} km içinde ${data.length} şarj istasyonu bulundu.`
    } catch (error) {
      this.statusTarget.textContent =
        error.message || "Beklenmeyen bir hata oluştu."
    }
  }

  addStationMarker(station) {
    const connections =
      station.connection_types.length > 0
        ? station.connection_types.join(", ")
        : "Bilinmiyor"

    const popup = `
      <div class="station-popup">
        <strong>${this.escapeHtml(station.name)}</strong>

        <p>
          ${this.escapeHtml(station.address || "Adres bulunamadı")}
        </p>

        <p>
          <b>Operatör:</b>
          ${this.escapeHtml(station.operator || "Bilinmiyor")}
        </p>

        <p>
          <b>Durum:</b>
          ${this.escapeHtml(station.status || "Bilinmiyor")}
        </p>

        <p>
          <b>Güç:</b>
          ${station.power_kw ? `${station.power_kw} kW` : "Bilinmiyor"}
        </p>

        <p>
          <b>Bağlantı:</b>
          ${this.escapeHtml(connections)}
        </p>
      </div>
    `

    return window.L.marker(
      [station.latitude, station.longitude],
      {
        icon: this.createStationIcon()
      }
    )
      .addTo(this.stationLayer)
      .bindPopup(popup)
  }

  createUserIcon() {
    return window.L.divIcon({
      className: "custom-map-icon user-map-icon",
      html: '<span class="map-pin"></span>',
      iconSize: [28, 28],
      iconAnchor: [14, 28],
      popupAnchor: [0, -28]
    })
  }

  createStationIcon() {
    return window.L.divIcon({
      className: "custom-map-icon station-map-icon",
      html: '<span class="map-pin"></span>',
      iconSize: [28, 28],
      iconAnchor: [14, 28],
      popupAnchor: [0, -28]
    })
  }

  escapeHtml(value) {
    const element = document.createElement("div")
    element.textContent = String(value)
    return element.innerHTML
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
}