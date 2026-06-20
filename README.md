# AI-Powered Stock Screener

Single-source project documentation for the complete system:
- `backend` (Node.js + Express + PostgreSQL)
- `stock_screener_app` (Flutter app)

`ARCHITECTURE.md` is kept separately for system design details.

## Tech Stack
- Flutter
- Node.js + Express
- PostgreSQL
- Redis (optional cache)
- Groq API (natural language query parsing)
- Finnhub API (market data)

## Repository Structure
```text
Stock_screener/
  backend/                     # API server, DB schema, services, routes
  stock_screener_app/          # Flutter mobile/web app
  ARCHITECTURE.md              # High-level architecture
  README.md                    # This file (single full guide)
```

## Core Features
- Natural-language stock screener (`POST /screener`)
- Watchlist management (`/api/watchlist/*`)
- Portfolio management (`/api/portfolio/*`)
- Alerts system with ownership checks (`/api/alerts/*`)
- Saved screeners (`/api/screeners/*`)
- Insights/advisory endpoints
- Admin/health endpoints
- Multi-user isolation test suite (`npm run test:multiuser`)

## Prerequisites
- Node.js 18+ recommended
- npm 8+
- PostgreSQL 14+
- Flutter SDK 3.x
- Android Studio / Xcode (for mobile builds)

## 1. Local Setup

### 1.1 Clone and install
```bash
git clone <your-repo-url>
cd Stock_screener
cd backend && npm install
cd ../stock_screener_app && flutter pub get
```

### 1.2 Configure backend environment
1. Copy `backend/.env.example` to `backend/.env`
2. Fill required values:
```env
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=stock_screener
DB_USER=postgres
DB_PASSWORD=your_password

GROQ_API_KEY=your_key
FINNHUB_API_KEY=your_key
```

Important optional flags:
- `DATABASE_URL` (cloud Postgres)
- `DB_SSL=true` (hosted DBs)
- `DISABLE_RATE_LIMIT=true` (only for controlled load tests)

### 1.3 Initialize database
From `backend/`:
```bash
npm run db:init
```

### 1.4 Run backend
From `backend/`:
```bash
npm start
```

Health checks:
- `http://localhost:5000/health`
- `http://localhost:5000/health/detailed`

### 1.5 Run Flutter app
From `stock_screener_app/`:
```bash
flutter run
```

API base URL resolution is in `stock_screener_app/lib/services/api_config.dart`:
- Uses `--dart-define=API_BASE_URL=...` when provided
- Defaults to `http://localhost:5000`

For Android device via USB:
```bash
adb reverse tcp:5000 tcp:5000
```

## 2. Useful Commands

### Backend (`backend/`)
```bash
npm start
npm run dev
npm test
npm run test:multiuser
npm run verify
npm run db:init
```

### Flutter (`stock_screener_app/`)
```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

## 3. Key API Endpoints

### Health
- `GET /health`
- `GET /health/detailed`

### Screener
- `POST /screener`
- `GET /cache/stats`
- `DELETE /cache`

### Portfolio
- `GET /api/portfolio/:userId`
- `POST /api/portfolio/add`
- `PUT /api/portfolio/update`
- `DELETE /api/portfolio/remove`

### Watchlist
- `GET /api/watchlist/:userId`
- `POST /api/watchlist/add`
- `DELETE /api/watchlist/remove`
- `GET /api/watchlist/:userId/check/:symbol`

### Alerts
- `GET /api/alerts/:userId`
- `POST /api/alerts`
- `PATCH /api/alerts/:alertId/read`
- `PATCH /api/alerts/:alertId/acknowledge`
- `PATCH /api/alerts/:alertId/dismiss`
- `DELETE /api/alerts/:alertId?userId=<id>`

### Saved Screeners
- `POST /api/screeners`
- `GET /api/screeners/:userId`
- `PATCH /api/screeners/:userId/:screenerId`
- `DELETE /api/screeners/:userId/:screenerId`

### User provisioning (app mapping)
- `POST /api/users/register`

## 4. Deployment

This repo includes `render.yaml` for Render blueprint deployment.

### Backend on Render
1. Push repo to GitHub
2. Create Render Blueprint from repo
3. Set secrets:
   - `GROQ_API_KEY`
   - `FINNHUB_API_KEY`
4. Run schema init once:
```bash
cd backend
npm run db:init
```

### Build Flutter release with deployed API URL
```bash
cd stock_screener_app
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-backend>.onrender.com --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-google-web-client-id>
```

APK build:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<your-backend>.onrender.com --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-google-web-client-id>
```

## 5. Multi-user Reliability Testing

100-user isolation/load test:
```bash
cd backend
TEST_BASE_URL=http://localhost:5000 TEST_USER_COUNT=100 TEST_CONCURRENCY=20 npm run test:multiuser
```

Notes:
- With default rate limiting, heavy burst tests can return `429`.
- For controlled stress runs only, use `DISABLE_RATE_LIMIT=true`.

## 6. Troubleshooting

- Backend not reachable from phone:
  - Use `adb reverse tcp:5000 tcp:5000`, or
  - Set `--dart-define=API_BASE_URL=http://<PC_IP>:5000`
- DB connection failures:
  - Recheck `DB_*` or `DATABASE_URL`
  - Ensure PostgreSQL is running and reachable
- Finnhub/Groq issues:
  - Verify API keys in `backend/.env`
  - Restart backend after updating env

## 7. Security and Production Notes
- Keep `.env` out of version control
- Keep rate limiting enabled in production
- Use SSL for hosted Postgres (`DB_SSL=true`)
- Protect admin endpoints before public deployment

## License
MIT
