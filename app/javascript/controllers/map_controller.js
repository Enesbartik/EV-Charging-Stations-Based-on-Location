import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "status"]

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
        const latitude = position.coords.latitude
        const longitude = position.coords.longitude
        const coordinates = [latitude, longitude]

        this.map.setView(coordinates, 14)

        window.L.marker(coordinates)
          .addTo(this.map)
          .bindPopup("Konumunuz")
          .openPopup()

        await this.loadStations(latitude, longitude)
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

  async loadStations(latitude, longitude) {
  this.statusTarget.textContent = "Yakındaki istasyonlar aranıyor..."

  const parameters = new URLSearchParams({
    latitude: latitude,
    longitude: longitude
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
        "Yakınınızda şarj istasyonu bulunamadı."

      return
    }

    const bounds = window.L.latLngBounds([
      [latitude, longitude]
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
      `${data.length} şarj istasyonu bulundu.`
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
        <p>${this.escapeHtml(station.address || "Adres bulunamadı")}</p>
        <p><b>Operatör:</b> ${this.escapeHtml(station.operator || "Bilinmiyor")}</p>
        <p><b>Durum:</b> ${this.escapeHtml(station.status || "Bilinmiyor")}</p>
        <p><b>Güç:</b> ${station.power_kw ? `${station.power_kw} kW` : "Bilinmiyor"}</p>
        <p><b>Bağlantı:</b> ${this.escapeHtml(connections)}</p>
      </div>
    `

    const marker = window.L
  .marker([station.latitude, station.longitude])
  .addTo(this.map)
  .bindPopup(popup)

    return marker
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