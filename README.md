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
> **Note**: The APK was not built because the `flutter` tool was not available in the generation environment. Follow these steps to build it:

1. Navigate to `mobile/flutter_app`.
2. Run `flutter create .` to generate platform-specific files (android, ios, etc.).
3. Run `flutter pub get`.
4. Run `dart run build_runner build` to generate Drift database code (`database.g.dart`).
5. Run `flutter run` to start the app on an emulator/device.

## ML Service
- Endpoint: `GET /recommend?customerId=...`
- Training: `POST /train`

## Backend API
- Import `postman_collection.json` into Postman to test endpoints.
