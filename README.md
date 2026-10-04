# 🃏 Yu-Gi-Oh! Card Collector — Full Stack Mobile & Backend System

[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688.svg?logo=fastapi)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B.svg?logo=flutter)](https://flutter.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1.svg?logo=postgresql)](https://www.postgresql.org)
[![SQLite](https://img.shields.io/badge/SQLite-Offline--First-003B57.svg?logo=sqlite)](https://www.sqlite.org)
[![Google ML Kit](https://img.shields.io/badge/ML%20Kit-OCR%20Text%20Recognition-4285F4.svg?logo=google)](https://developers.google.com/ml-kit)

Sistema completo (Backend asíncrono + App Móvil Offline-First) para coleccionistas de cartas Yu-Gi-Oh!, con reconocimiento óptico de caracteres (OCR) on-device mediante **Google ML Kit**, sincronización periódica con la API de **YGOPRODeck**, y álbum digital con precios de mercado en tiempo real.

---

## 🏛️ Arquitectura del Sistema

```
                    ┌──────────────────────────────────┐
                    │      YGOPRODeck Public API       │
                    │  (db.ygoprodeck.com/api/v7/...)  │
                    └─────────────────┬────────────────┘
                                      │ HTTPS (Throttle 1 req/s)
                                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        BACKEND (Docker Compose)                        │
│                                                                        │
│   ┌─────────────────┐       ┌──────────────────────────────────────┐   │
│   │   APScheduler   │◄─────►│          FastAPI Async API           │   │
│   │   (Background)  │       │  - Auth (JWT + Passlib)              │   │
│   │  - Sync Cartas  │       │  - Cards (/cards/set/{code})         │   │
│   │  - Sync Precios │       │  - Inventory CRUD (Atomic UPSERT)    │   │
│   │  - SQLite Dump  │       │  - Sets & Missing Cards Tracker      │   │
│   └────────┬────────┘       │  - Sync (/sync/database/lite)        │   │
│            │                └──────────────────┬───────────────────┘   │
│            ▼                                   ▼                       │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │              PostgreSQL 15 (Fuente de la Verdad)               │   │
│   │  master_cards | master_sets | card_sets_link | user_inventory   │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                    ▲                                   │
│   ┌─────────────────┐              │                                   │
│   │  Redis 7 Cache  │◄─────────────┘                                   │
│   │ (Rate Limiting) │                                                  │
│   └─────────────────┘                                                  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ HTTPS / REST (JWT)
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      APP MÓVIL (Flutter 3.22+)                         │
│                                                                        │
│  ┌────────────────────────┐         ┌──────────────────────────────┐   │
│  │   Cámara + ML Kit OCR  │         │    SQLite Local Cache        │   │
│  │   - 2 FPS Throttle     │         │    (yugioh_lite.db)          │   │
│  │   - Regex Set Code     │────────►│    - 13.000 cartas maestras  │   │
│  │   - Feedback háptico   │         │    - Búsqueda y OCR offline  │   │
│  └────────────────────────┘         └──────────────┬───────────────┘   │
│                                                    │                   │
│  ┌────────────────────────┐         ┌──────────────▼───────────────┐   │
│  │  Riverpod 2.5 State    │◄───────►│  Cola Offline (FIFO)         │   │
│  │  - Auth & Token Ref    │         │  - inventory.db mutations    │   │
│  │  - Inventory Binder    │         │  - Auto-flush al haber red   │   │
│  └────────────────────────┘         └──────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Estructura del Repositorio

```
.
├── backend/
│   ├── alembic/                      # Migraciones de base de datos
│   ├── app/
│   │   ├── api/routers/              # Endpoints: auth, cards, inventory, sets, sync
│   │   ├── core/                     # Config, DB, Security JWT, Rate Limiter
│   │   ├── models/                   # Modelos relacionales SQLAlchemy
│   │   ├── schemas/                  # Validaciones Pydantic v2
│   │   ├── services/                 # YGOPRODeck sync y generador SQLite Lite
│   │   └── main.py                   # FastAPI app con middlewares y ciclo de vida
│   ├── tests/                        # Tests unitarios y de integración con SQLite in-memory
│   ├── seed_demo_data.py             # Script de datos demo (Blue-Eyes, Exodia, etc.)
│   ├── Dockerfile                    # Contenedor optimizado Python 3.11
│   ├── requirements.txt
│   └── README.md
│
├── mobile/
│   ├── android/app/src/main/
│   │   └── AndroidManifest.xml       # Permisos de cámara, red y modelo OCR ML Kit
│   ├── lib/
│   │   ├── core/                     # Tema Oro Egipcio, Cliente Dio, Regex OCR, Cola Offline
│   │   ├── data/                     # DataSources SQLite, Modelos y Repositorios Híbridos
│   │   ├── presentation/
│   │   │   ├── navigation/           # GoRouter con ShellRoute y navegación por pestañas
│   │   │   ├── providers/            # Riverpod StateNotifiers
│   │   │   ├── screens/              # Escáner OCR, Álbum, Catálogo, Sets, Ajustes, Login
│   │   │   └── widgets/              # CardItemTile, StatsHeader, OfflineBanner
│   │   └── main.dart
│   ├── test/                         # Tests unitarios del algoritmo OCR
│   ├── pubspec.yaml
│   └── README.md
│
├── docker-compose.yml                # Orquestación: PostgreSQL 15 + Redis 7 + Backend
├── .env.example                      # Plantilla de variables de entorno
└── README.md                         # Este documento
```

---

## 🚀 Puesta en Marcha Rápida (5 Minutos)

### Paso 1: Levantar el Backend con Docker

```powershell
# Clona y entra en el proyecto
cd "C:\Users\jonyp\Desktop\apk yugui"

# Levanta Postgres, Redis y la API en segundo plano
docker compose up --build -d
```

> **Verificación:** Visita **http://localhost:8000/docs** para ver la documentación interactiva de Swagger UI.

### Paso 2: (Opcional pero recomendado) Cargar Datos Demo

Para no esperar la descarga inicial de las 13.000 cartas de YGOPRODeck, puedes poblar datos demo al instante:

```powershell
docker compose exec backend python seed_demo_data.py
```

Esto generará:
- **Usuario de prueba:** `yugi@duel.com` / `password123`
- **Cartas icónicas:** *Blue-Eyes White Dragon*, *Dark Magician*, *Red-Eyes Black Dragon*, *Exodia the Forbidden One*, *Pot of Greed*.
- **Expansiones:** *LOB*, *SDK*, *SDY*, *MP21*.
- **Archivo SQLite:** `yugioh_lite.db` listo para ser descargado por la app móvil.

---

### Paso 3: Ejecutar la App Móvil Flutter

1. Abrir terminal en la carpeta `mobile`:
```powershell
cd mobile
flutter pub get
```

2. Ejecutar en emulador Android o dispositivo físico:
```powershell
flutter run
```

> **Nota para emulador Android:** La app viene configurada para conectarse a `http://10.0.2.2:8000/api/v1`.  
> Si usas un dispositivo móvil físico conectado por USB, ingresa tu IP local (ej: `http://192.168.1.50:8000/api/v1`) en [app_constants.dart](file:///C:/Users/jonyp/Desktop/apk%20yugui/mobile/lib/core/constants/app_constants.dart).

---

## 🧪 Ejecución de Tests

### Tests del Backend (Pytest):
```powershell
docker compose exec backend pytest -v
```
> Ejecuta 18 tests de integración que prueban el registro, login, refresh tokens, búsqueda de cartas, lookup OCR, el **UPSERT atómico** ante escaneos duplicados, y la exportación SQLite.

### Tests de la App Móvil (Flutter Test):
```powershell
cd mobile
flutter test
```
> Valida el parser de expresiones regulares de códigos de expansión bajo diferentes condiciones de ruido y formatos.

---

## 📸 Cómo Funciona el Escaneo OCR de Cartas

1. El usuario abre la pestaña **Escanear** en la app móvil.
2. La cámara inicia una transmisión de frames procesada a un máximo de **2 FPS** para no saturar la CPU ni sobrecalentar la batería.
3. El motor **Google ML Kit Text Recognition** procesa los bloques de texto.
4. El extractor `OcrRegex` filtra candidatos con el patrón de código Yu-Gi-Oh! (ej. `LOB-001`, `MP21-EN001`).
5. Se consulta la base de datos local SQLite (`yugioh_lite.db`) en **0 ms**.
6. Al encontrar la carta, la app emite una **vibración háptica** y despliega el modal de confirmación.
7. El usuario confirma la **Edición** (*1st Edition* / *Unlimited*), el **Estado** (*Near Mint*, etc.) y la cantidad.
8. La carta se añade al inventario local instantáneamente y se encola para su sincronización en el backend.
