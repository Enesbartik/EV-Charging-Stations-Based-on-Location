# EV Charging Map

Bu proje Leaflet + OpenStreetMap tabanlı, kullanıcı konumunu ve Open Charge Map istasyonlarını harita üzerinde gösterir.

## Ortam değişkeni ayarı

Google adres araması için browser tarafında kullanılacak API anahtarı şu ortam değişkeni üzerinden alınır:

- `GOOGLE_MAPS_BROWSER_API_KEY`

Aşağıdaki örnek gibi bir değer tanımlayabilirsiniz:

```bash
export GOOGLE_MAPS_BROWSER_API_KEY="your-key-here"
```

Rails credentials kullanmak isterseniz `config/credentials.yml.enc` içinde aşağıdaki anahtarı tanımlayabilirsiniz:

```yaml
google_maps_browser_api_key: your-key-here
```

> Gerçek API anahtarı repository içine yazılmaz. Bu dosyayı commit etmeyin.

## Yerel çalıştırma

```bash
bin/setup
bin/rails server
```

## Testler

```bash
bin/rails test
```

