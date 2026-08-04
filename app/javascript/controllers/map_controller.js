import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "status", "distance", "search"]

  connect() {
    if (!window.L) {
      this.statusTarget.textContent = "Harita kütüphanesi yüklenemedi."
      return
    }

    const istanbul = [41.0082, 28.9784]

    this.map = window.L.map(this.canvasTarget).setView(istanbul, 11)
    this.searchAbortController = null
    this.stationRequestController = null
    this.activeRequestId = 0
    this.latestStationRequestId = 0

    window.L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    this.searchResultLayer = window.L.layerGroup().addTo(this.map)
    this.savedStationLayer = window.L.layerGroup().addTo(this.map)
    this.favoriteExternalIds = new Set()
    this.userMarker = null
    this.searchAreaCircle = null

    this.attachAutocomplete()
    this.findUserLocation()
  }

  attachAutocomplete() {
    if (!this.hasGoogleMapsApiKey() || !window.google?.maps?.places?.Autocomplete) {
      return
    }

    this.autocomplete = new window.google.maps.places.Autocomplete(
      this.searchTarget,
      {
        types: ["address", "establishment"],
        fields: ["formatted_address", "geometry", "name"]
      }
    )

    this.autocomplete.addListener("place_changed", () => {
      const place = this.autocomplete.getPlace()
      const location = place?.geometry?.location

      if (!location) {
        this.statusTarget.textContent = "Seçilen adres için koordinat bulunamadı."
        return
      }

      this.setActiveSearchLocation({
        formatted_address: place.formatted_address || place.name,
        latitude: location.lat(),
        longitude: location.lng()
      })
    })
  }

  useUserLocation() {
    this.findUserLocation()
  }

  findUserLocation() {
    if (!navigator.geolocation) {
      this.statusTarget.textContent =
        "Tarayıcınız konum özelliğini desteklemiyor."
      return
    }

    this.statusTarget.textContent = "Konumunuz alınıyor..."

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        this.latitude = position.coords.latitude
        this.longitude = position.coords.longitude
        this.displayedAddress = "Konumunuz"

        const coordinates = [this.latitude, this.longitude]

        if (this.userMarker) {
          this.userMarker.remove()
        }

        this.userMarker = window.L.marker(coordinates, {
          icon: this.createUserIcon()
        })
          .addTo(this.map)
          .bindPopup("Konumunuz")
          .openPopup()

        this.searchResultLayer.clearLayers()
        this.drawSearchAreaCircle()
        this.fitMapToSearchArea()

        await Promise.allSettled([
          this.loadStations(),
          this.loadSavedStations()
        ])
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

  async searchAddress() {
    const query = this.searchTarget.value.trim()

    if (!query) {
      this.statusTarget.textContent = "Lütfen bir adres veya ilçe girin."
      return
    }

    this.statusTarget.textContent = "Konum aranıyor..."

    if (!this.hasGoogleMapsApiKey()) {
      this.statusTarget.textContent =
        "Google Maps API anahtarı tanımlı değil. Adres arama özelliği devre dışı."
      return
    }

    if (this.searchAbortController) {
      this.searchAbortController.abort()
    }

    this.searchAbortController = new AbortController()
    const requestId = ++this.activeRequestId

    try {
      const response = await fetch(
        `/maps/geocode?query=${encodeURIComponent(query)}`,
        {
          headers: { Accept: "application/json" },
          signal: this.searchAbortController.signal
        }
      )

      const payload = await response.json()

      if (!response.ok) {
        throw new Error(payload.error || "Adres bulunamadı.")
      }

      if (requestId !== this.activeRequestId) {
        return
      }

      const result = payload.results?.[0]

      if (!result) {
        this.statusTarget.textContent = "Adres bulunamadı."
        return
      }

      this.setActiveSearchLocation(result)
    } catch (error) {
      if (error.name === "AbortError") {
        return
      }

      this.statusTarget.textContent = error.message || "Adres bulunamadı."
    }
  }

  async setActiveSearchLocation(result) {
    const coordinates = [result.latitude, result.longitude]
    this.latitude = result.latitude
    this.longitude = result.longitude
    this.displayedAddress = result.formatted_address || result.name || "Seçilen adres"

    if (this.userMarker) {
      this.userMarker.setLatLng(coordinates)
      this.userMarker.bindPopup(this.escapeHtml(this.displayedAddress))
    } else {
      this.userMarker = window.L.marker(coordinates, {
        icon: this.createUserIcon()
      })
        .addTo(this.map)
        .bindPopup(this.escapeHtml(this.displayedAddress))
    }

    this.userMarker.openPopup()

    this.searchResultLayer.clearLayers()
    this.drawSearchAreaCircle()
    this.fitMapToSearchArea()

    await Promise.allSettled([
      this.loadStations(),
      this.loadSavedStations()
    ])
  }

  async changeDistance() {
    if (this.latitude === undefined || this.longitude === undefined) {
      return
    }

    this.searchResultLayer.clearLayers()
    this.drawSearchAreaCircle()
    this.fitMapToSearchArea()
    await Promise.allSettled([
      this.loadStations(),
      this.loadSavedStations()
    ])
  }

  async loadStations() {
    const distance = Number(this.distanceTarget.value)
    const allowedDistances = [1, 2, 5, 10, 15, 20, 25, 30]

    if (!allowedDistances.includes(distance)) {
      this.statusTarget.textContent = "Arama mesafesi 1, 2, 5, 10, 15, 20, 25 veya 30 km olmalıdır."
      return
    }

    if (this.stationRequestController) {
      this.stationRequestController.abort()
    }

    this.stationRequestController = new AbortController()
    const requestId = ++this.latestStationRequestId

    this.statusTarget.textContent = `${distance} km içindeki şarj istasyonları aranıyor...`

    const parameters = new URLSearchParams({
      latitude: this.latitude,
      longitude: this.longitude,
      distance: distance
    })

    try {
      const response = await fetch(`/charging_stations?${parameters.toString()}`, {
        headers: {
          Accept: "application/json"
        },
        signal: this.stationRequestController.signal
      })

      if (requestId !== this.latestStationRequestId) {
        return
      }

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "İstasyonlar alınamadı.")
      }

      if (requestId !== this.latestStationRequestId) {
        return
      }

      const visibleStations = data.filter((station) => {
        if (!station.latitude || !station.longitude) {
          return false
        }

        return this.isInsideSearchArea(station.latitude, station.longitude)
      })

      const nonFavoriteStations = visibleStations.filter((station) => {
        const externalId = this.externalIdForApiStation(station)

        return !externalId || !this.favoriteExternalIds.has(String(externalId))
      })

      if (nonFavoriteStations.length === 0) {
        this.statusTarget.textContent = `${distance} km içinde şarj istasyonu bulunamadı.`
        return
      }

      nonFavoriteStations.forEach((station) => {
        if (requestId !== this.latestStationRequestId) {
          return
        }

        this.addStationMarker(station)
      })

      this.statusTarget.textContent = `${distance} km içinde ${nonFavoriteStations.length} şarj istasyonu bulundu.`
    } catch (error) {
      if (error.name === "AbortError") {
        return
      }

      this.statusTarget.textContent = error.message || "Beklenmeyen bir hata oluştu."
    }
  }

  isInsideSearchArea(latitude, longitude) {
    const lat = Number(latitude)
    const lng = Number(longitude)
    const centerLat = Number(this.latitude)
    const centerLng = Number(this.longitude)
    const selectedDistanceKm = Number(this.distanceTarget.value)

    if (
      !Number.isFinite(lat) ||
      !Number.isFinite(lng) ||
      !Number.isFinite(centerLat) ||
      !Number.isFinite(centerLng) ||
      !Number.isFinite(selectedDistanceKm)
    ) {
      return false
    }

    const center = window.L.latLng(centerLat, centerLng)
    const stationPoint = window.L.latLng(lat, lng)
    const radiusMeters = selectedDistanceKm * 1000

    return center.distanceTo(stationPoint) <= radiusMeters
  }

  externalIdForApiStation(station) {
    return station.external_id || station.id || station.ID || station.externalId
  }

  addStationMarker(station) {
    const favorite = station.favorite === true
    const connections =
      station.connection_types?.length > 0
        ? station.connection_types.join(", ")
        : "Bilinmiyor"

    const popup = `
      <div class="station-popup">
        <strong>${this.escapeHtml(station.name)}</strong>

        <p>
          ${this.escapeHtml(station.address || "Adres bulunamadı")}
        </p>

        ${favorite ? "<p><b>★ Favori</b></p>" : ""}

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

    return window.L.marker([station.latitude, station.longitude], {
      icon: this.createStationIcon(favorite)
    })
      .addTo(this.searchResultLayer)
      .bindPopup(popup)
  }

  async loadSavedStations() {
    try {
      const response = await fetch("/stations.json", {
        headers: {
          Accept: "application/json"
        }
      })

      const stations = await response.json()

      if (!response.ok) {
        throw new Error("Kayıtlı istasyonlar alınamadı.")
      }

      this.favoriteExternalIds = new Set(
        stations
          .filter((station) =>
            station.favorite &&
            station.source !== "manual" &&
            station.external_id
          )
          .map((station) => String(station.external_id))
      )

      this.savedStationLayer.clearLayers()

      stations.forEach((station) => {
        this.addSavedStationMarker(station)
      })
    } catch (error) {
      console.error("Kayıtlı istasyon hatası:", error)
    }
  }

  addSavedStationMarker(station) {
    const favoriteText = station.favorite
      ? "<p><b>★ Favori istasyon</b></p>"
      : ""

    const popup = `
      <div class="station-popup">
        <strong>${this.escapeHtml(station.name)}</strong>

        <p>
          ${this.escapeHtml(station.address || "Adres belirtilmemiş")}
        </p>

        ${favoriteText}

        <p>
          <b>Enlem:</b> ${station.latitude}
        </p>

        <p>
          <b>Boylam:</b> ${station.longitude}
        </p>

        <a
          href="/stations/${station.id}/edit"
          class="popup-edit-link"
        >
          İstasyonu Düzenle
        </a>
      </div>
    `

    return window.L.marker([station.latitude, station.longitude], {
      icon: this.createSavedStationIcon(station.favorite)
    })
      .addTo(this.savedStationLayer)
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

  createStationIcon(isFavorite) {
    const className = isFavorite
      ? "custom-map-icon station-map-icon favorite"
      : "custom-map-icon station-map-icon"

    return window.L.divIcon({
      className,
      html: '<span class="map-pin"></span>',
      iconSize: [28, 28],
      iconAnchor: [14, 28],
      popupAnchor: [0, -28]
    })
  }

  createSavedStationIcon(isFavorite) {
    const className = isFavorite
      ? "custom-map-icon saved-station-map-icon favorite"
      : "custom-map-icon saved-station-map-icon"

    return window.L.divIcon({
      className,
      html: '<span class="map-pin"></span>',
      iconSize: [28, 28],
      iconAnchor: [14, 28],
      popupAnchor: [0, -28]
    })
  }

  drawSearchAreaCircle() {
    if (!this.latitude || !this.longitude) {
      return
    }

    const radiusMeters = Number(this.distanceTarget.value) * 1000

    if (this.searchAreaCircle) {
      this.map.removeLayer(this.searchAreaCircle)
    }

    this.searchAreaCircle = window.L.circle(
      [this.latitude, this.longitude],
      {
        radius: radiusMeters,
        color: "#2563eb",
        weight: 2,
        dashArray: "8 6",
        fillColor: "#60a5fa",
        fillOpacity: 0.06,
        interactive: false
      }
    ).addTo(this.map)
  }

  fitMapToSearchArea() {
    if (!this.searchAreaCircle) {
      return
    }

    this.map.invalidateSize()

    window.requestAnimationFrame(() => {
      this.map.fitBounds(this.searchAreaCircle.getBounds(), {
        padding: [35, 35],
        maxZoom: 16,
        animate: true
      })
    })
  }

  hasGoogleMapsApiKey() {
    return Boolean(this.element.dataset.googleMapsApiKey)
  }

  escapeHtml(value) {
    const element = document.createElement("div")
    element.textContent = String(value)
    return element.innerHTML
  }

  disconnect() {
    if (this.stationRequestController) {
      this.stationRequestController.abort()
    }

    if (this.map) {
      this.map.remove()
    }
  }
}