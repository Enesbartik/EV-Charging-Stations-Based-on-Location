import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const L = window.L

    if (!L) {
      this.element.textContent = "Harita kütüphanesi yüklenemedi."
      return
    }

    const istanbulCoordinates = [41.0082, 28.9784]

    this.map = L.map(this.element).setView(istanbulCoordinates, 12)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    L.marker(istanbulCoordinates)
      .addTo(this.map)
      .bindPopup("İstanbul merkez")
      .openPopup()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
}