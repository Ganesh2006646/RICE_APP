# RiceAgent

Full-stack agent app for rice-mill orders.

## Structure
- `mobile/flutter_app`: Flutter Android app
- `backend/api`: Node.js + Fastify + Prisma backend
- `ml`: Python FastAPI ML microservice

## Prerequisites
- Docker & Docker Compose
- Flutter SDK (for mobile app)
- Node.js 20+ (for local backend dev)

## Quick Start (Backend & ML)
1. Create a `.env` file in `backend/api` with:
   ```
   DATABASE_URL="postgresql://user:password@postgres:5432/riceagent?schema=public"
   GMAIL_OAUTH_CLIENT_ID="your_client_id"
   GMAIL_OAUTH_CLIENT_SECRET="your_client_secret"
   GMAIL_OAUTH_REFRESH_TOKEN="your_refresh_token"
   ```
2. Run `docker-compose up --build` from the root directory.
   - Backend: http://localhost:3000
   - ML: http://localhost:8000
   - Postgres: localhost:5432

## Mobile App Setup

1. Navigate to `mobile/flutter_app`.
2. Run `flutter pub get` to install dependencies.
3. Run `dart run build_runner build` to generate Drift database code (`database.g.dart`).
4. Run `flutter run` to start the app on an emulator/device.

### Building Release APK

**Windows:**
```bash
cd mobile/flutter_app
build_release.bat
```

**Linux/Mac:**
```bash
cd mobile/flutter_app
chmod +x build_release.sh
./build_release.sh
```

**Manual Build:**
```bash
cd mobile/flutter_app
flutter build apk --release
```

**Build Optimization:**
- Material Icons font is automatically tree-shaken during release builds
- Reduces font size from ~1.6MB to ~10KB (99.4% reduction)
- Only icons actually used in the app are included
- This optimization is enabled by default in Flutter release builds

**Output:** `build/app/outputs/flutter-apk/app-release.apk` (~63MB)

## ML Service
- Endpoint: `GET /recommend?customerId=...`
- Training: `POST /train`

## Backend API
- Import `postman_collection.json` into Postman to test endpoints.
