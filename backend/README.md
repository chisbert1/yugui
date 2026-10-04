# 🃏 Yu-Gi-Oh! Collector — Backend API

Backend en Python/FastAPI para la app móvil de coleccionismo de cartas Yu-Gi-Oh!.

## Stack

| Componente | Tecnología |
|------------ |-----------|
| Framework | FastAPI 0.115 (async) |
| Base de Datos | PostgreSQL 15 |
| ORM | SQLAlchemy 2.0 (async) |
| Migraciones | Alembic |
| Caché / Rate Limit | Redis 7 |
| Scheduler | APScheduler 3 |
| Auth | JWT (python-jose + bcrypt) |
| HTTP Client | httpx + Tenacity |

## Prerequisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y corriendo
- Puerto `8000`, `5432` y `6379` libres en tu máquina

## 🚀 Arranque Rápido

```bash
# 1. Clonar / abrir el directorio raíz del proyecto
cd "apk yugui"

# 2. Levantar todos los servicios (PostgreSQL, Redis, Backend)
docker compose up --build

# La primera vez, el backend:
#   ✓ Ejecuta las migraciones Alembic automáticamente
#   ✓ Detecta que la BD está vacía y lanza la sync inicial con YGOPRODeck
#     (puede tardar 5-10 minutos descargando ~12k cartas)

# 3. Abrir Swagger UI
#    http://localhost:8000/docs
```

## 📁 Estructura del Proyecto

```
backend/
├── app/
│   ├── main.py                  # FastAPI app factory + lifecycle
│   ├── scheduler.py             # APScheduler jobs
│   ├── core/
│   │   ├── config.py            # Pydantic Settings (env vars)
│   │   ├── database.py          # Async SQLAlchemy engine + session
│   │   ├── security.py          # JWT + bcrypt
│   │   └── redis_client.py      # Redis connection pool
│   ├── models/
│   │   ├── user.py
│   │   ├── master_set.py
│   │   ├── master_card.py
│   │   ├── card_sets_link.py
│   │   ├── user_inventory.py
│   │   └── sync_metadata.py
│   ├── services/
│   │   ├── ygoprodeck_client.py # HTTP client con throttle + retry
│   │   ├── sync_service.py      # Lógica de UPSERT masivo
│   │   └── sqlite_exporter.py   # Generador del dump SQLite para móvil
│   └── api/
│       ├── deps.py              # Dependencias compartidas (auth, db)
│       └── routers/
│           ├── auth.py          # /auth/register, /login, /refresh
│           ├── cards.py         # /cards/set/{code}, /search, /{id}
│           ├── inventory.py     # /inventory/me, /add, /{id}
│           └── sync.py          # /sync/database/lite, /trigger/*
├── alembic/
│   ├── env.py
│   └── versions/
│       └── 0001_initial_schema.py
├── tests/
│   └── test_sync_service.py
├── Dockerfile
├── requirements.txt
└── alembic.ini
```

## 🔑 Endpoints principales

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Crear cuenta |
| POST | `/api/v1/auth/login` | Obtener JWT |
| GET | `/api/v1/cards/set/{code}` | ⚡ Lookup OCR (ej: `DUSA-EN001`) |
| GET | `/api/v1/cards/search?q=dark+magician` | Búsqueda por nombre |
| POST | `/api/v1/inventory/add` | Añadir carta a colección |
| GET | `/api/v1/inventory/me` | Ver mi colección |
| GET | `/api/v1/sync/database/lite` | Descargar DB SQLite para móvil |
| GET | `/health` | Health check |

## 🧪 Tests

```bash
# Entrar al contenedor del backend
docker compose exec backend bash

# Ejecutar tests
pytest -v
```

## ⚙️ Variables de Entorno

Ver el archivo `.env` en la raíz del proyecto. Las más importantes:

| Variable | Descripción |
|----------|-------------|
| `DATABASE_URL` | URL async de PostgreSQL |
| `REDIS_URL` | URL de Redis |
| `APP_SECRET_KEY` | Secreto para firmar JWT (¡cambiar en producción!) |
| `API_SERVICE_KEY` | Clave para endpoints admin de sync |
| `SYNC_CARDS_INTERVAL_DAYS` | Cada cuántos días sincronizar cartas (default: 7) |

## 🔄 Sincronización Manual

Para forzar una re-sincronización sin esperar al scheduler:

```bash
curl -X POST http://localhost:8000/api/v1/sync/trigger/cards \
  -H "X-Service-Key: internal_service_key_for_sync_endpoints"
```

## 📱 Descarga SQLite para App Móvil

```bash
# Con un JWT válido:
curl -O http://localhost:8000/api/v1/sync/database/lite \
  -H "Authorization: Bearer YOUR_JWT_HERE"
```

El header `X-DB-Hash` contiene el SHA-256 del archivo para verificación de integridad en el móvil.

---

## Próxima Fase

**Fase 3:** App móvil Flutter/React Native con Repository Pattern y pantallas de inventario.
