# RiceAgent Deployment Guide

This guide covers how to deploy the RiceAgent Backend and build the Android Mobile App.

## 1. Backend Deployment

The backend uses Node.js, Fastify, Prisma, and PostgreSQL. You can deploy it using Docker or manually on a VPS.

### Prerequisites
- A PostgreSQL database (e.g., Supabase, Railway, AWS RDS, or a local Postgres instance).
- A server with Docker installed (if using Docker) or Node.js v20+ (if manual).

### Environment Variables
You must set the following environment variables on your server:

```env
DATABASE_URL="postgresql://user:password@host:5432/db_name?schema=public"
PORT=3000
```

### Option A: Using Docker (Recommended)

1.  **Build the Image**:
    Navigate to `backend/api` and run:
    ```bash
    docker build -t rice-agent-backend .
    ```

2.  **Run the Container**:
    ```bash
    docker run -d -p 3000:3000 -e DATABASE_URL="<YOUR_DB_URL>" rice-agent-backend
    ```

### Option B: Manual Deployment (Node.js)

1.  **Clone & Install**:
    Transfer the `backend/api` code to your server.
    ```bash
    cd backend/api
    npm install
    ```

2.  **Build**:
    ```bash
    npm run build
    ```

3.  **Database Migration**:
    ```bash
    npx prisma migrate deploy
    ```

4.  **Start**:
    ```bash
    npm start
    ```
    (Use a process manager like `pm2` for production: `pm2 start dist/server.js`)

## 2. Mobile App Deployment (Android)

The mobile app is built with Flutter.

### Prerequisites
- Flutter SDK installed.
- Android Studio / Android SDK properly configured.

### Build APK

1.  **Navigate to the App Directory**:
    ```bash
    cd mobile/flutter_app
    ```

2.  **Update Base URL**:
    Ensure the API URL in your code (e.g., in `main.dart` or a config file) points to your **deployed backend URL**, not `localhost`.

3.  **Build release APK**:
    ```bash
    flutter build apk --release
    ```

    The output APK will be located at:
    `build/app/outputs/flutter-apk/app-release.apk`

4.  **Install**:
    Transfer this `.apk` file to your Android phone and install it.

## 3. Machine Learning Service (Optional)

If using the ML service in `ml/`:
1.  Navigate to `ml/`.
2.  Build Docker image: `docker build -t rice-agent-ml .`
3.  Run: `docker run -p 5000:5000 rice-agent-ml`
