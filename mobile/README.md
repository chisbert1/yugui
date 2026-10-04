# 📱 Yu-Gi-Oh! Collector — Flutter Mobile App

App móvil offline-first con reconocimiento OCR (Google ML Kit) para coleccionistas de cartas Yu-Gi-Oh!.

---

## ⚡ Características Principales

- 📸 **Escaneo OCR en Tiempo Real:** Reconocimiento con Google ML Kit Text Recognition v2 a 2 FPS, con visor objetivo y retroalimentación háptica.
- 📦 **Offline-First:** Catálogo local completo (~13.000 cartas) almacenado en SQLite (`yugioh_lite.db`). Búsquedas y validaciones de escaneo sin latencia de red ni conexión a internet requerida.
- 🔄 **Cola Offline FIFO:** Si agregas cartas o modificas cantidades sin conexión, los cambios se encolan en SQLite y se sincronizan automáticamente con el backend al restaurar internet.
- 💎 **Gestión de Álbum Digital:** Seguimiento de cantidades, ediciones (*1st Edition*, *Unlimited*, *Limited*), estados de conservación (*Near Mint*, etc.), y valor estimado en TCGPlayer/Cardmarket.
- 📚 **Completador de Sets:** Seguimiento porcentual de coleccionismo por expansión con filtro rápido de "Solo cartas faltantes".
- 🎨 **Diseño Duelista Premium:** Tema oscuro inspirado en el Antiguo Egipto (Oro del Milenio `#FFD700`, Obsidiana `#0F111A` y paleta de atributos Yu-Gi-Oh!).

---

## 🚀 Requisitos Previos

- Flutter SDK 3.22+ (`>=3.4.0 <4.0.0`)
- Android Studio / VS Code con extensión Flutter
- Backend de Yu-Gi-Oh! Collector corriendo (`docker compose up`)

---

## 📲 Puesta en Marcha

### 1. Instalar Dependencias

Desde la carpeta `mobile`:
```bash
flutter pub get
```

### 2. Configurar la URL del Backend

En `lib/core/constants/app_constants.dart`:
- **Emulador Android:** `http://10.0.2.2:8000/api/v1` (configurado por defecto)
- **Simulador iOS:** `http://localhost:8000/api/v1`
- **Dispositivo Físico:** `http://<IP-DE-TU-PC-EN-LA-RED-LOCAL>:8000/api/v1`

### 3. Ejecutar la Aplicación

```bash
flutter run
```

---

## 🧪 Ejecutar Tests

```bash
flutter test
```

---

## 📂 Arquitectura de Carpetas

```
mobile/
├── android/
│   └── app/src/main/AndroidManifest.xml   # Permisos de Cámara e Internet + ML Kit
├── lib/
│   ├── main.dart                          # Punto de entrada de la aplicación
│   ├── core/
│   │   ├── constants/                     # Constantes, endpoints y claves
│   │   ├── network/                       # Dio ApiClient con JWT refresh y conectividad
│   │   ├── sync/                          # SyncManager (descarga SQLite) y OfflineQueueManager
│   │   ├── theme/                         # AppTheme (colores de atributos, oro, tipografía)
│   │   └── utils/                         # OcrRegex (normalización y detección de códigos)
│   ├── data/
│   │   ├── datasources/local/             # DatabaseHelper (SQLite lite + inventario local)
│   │   ├── models/                        # CardModel, CardSetLinkModel, InventoryItemModel, etc.
│   │   └── repositories/                  # AuthRepository, CardRepository, InventoryRepository
│   └── presentation/
│       ├── navigation/                    # GoRouter con ShellRoute y redirección de sesión
│       ├── providers/                     # Riverpod Notifiers (Auth, Inventory, Sync, Search)
│       ├── screens/                       # Scanner, Inventory, Cards, Sets, Settings, Login
│       └── widgets/                       # CardItemTile, OfflineBanner, StatsHeader
├── test/
│   └── ocr_regex_test.dart                # Tests unitarios del regex de códigos OCR
└── pubspec.yaml
```
