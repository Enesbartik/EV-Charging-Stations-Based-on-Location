import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "status"]

  connect() {
    const L = window.L

    if (!L) {
      this.statusTarget.textContent = "Harita kütüphanesi yüklenemedi."
      return
    }

    const istanbul = [41.0082, 28.9784]

    this.map = L.map(this.canvasTarget).setView(istanbul, 11)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
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
      (position) => {
        const latitude = position.coords.latitude
        const longitude = position.coords.longitude
        const userCoordinates = [latitude, longitude]

        this.map.setView(userCoordinates, 14)

        this.userMarker = window.L.marker(userCoordinates)
          .addTo(this.map)
          .bindPopup("Konumunuz")
          .openPopup()

        this.statusTarget.textContent =
          "Konumunuz bulundu. Yakındaki istasyonlar hazırlanıyor."
      },

      () => {
        this.statusTarget.textContent =
          "Konum alınamadı. İstanbul varsayılan konum olarak gösteriliyor."
      },

      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 60000
      }
    )
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
}