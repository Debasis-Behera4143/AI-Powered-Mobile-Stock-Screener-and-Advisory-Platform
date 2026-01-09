# AI-Powered Stock Screener Backend

A production-ready Node.js backend for an AI-powered stock screening application with natural language query support.

## 🚀 Features

- **Market Data Integration**: Fetch stock fundamentals from Alpha Vantage API
- **AI Query Parser**: Convert natural language queries to structured filters using LLM
- **PostgreSQL Database**: Efficient storage of stock symbols and fundamentals
- **RESTful APIs**: Clean endpoints for Flutter mobile app integration
- **Security**: SQL injection protection, rate limiting, CORS support
- **Educational**: Comprehensive comments explaining every concept

## 📋 Prerequisites

- **Node.js** (v16 or higher)
- **PostgreSQL** (v12 or higher)
- **Alpha Vantage API Key** (free at https://www.alphavantage.co/support/#api-key)
- **OpenAI API Key** (optional, for LLM features)

## 🛠️ Installation

### 1. Clone and Install Dependencies

```bash
cd backend
npm install
```

### 2. Setup PostgreSQL Database

**Option A: Using PostgreSQL CLI**
```bash
# Login to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE stock_screener;

# Exit
\q
```

**Option B: Using pgAdmin**
- Open pgAdmin
- Right-click Databases → Create → Database
- Name: `stock_screener`

### 3. Configure Environment Variables

```bash
# Copy example env file
cp .env.example .env

# Edit .env with your actual values
notepad .env  # Windows
nano .env     # Linux/Mac
```

**Required variables:**
```env
DB_PASSWORD=your_postgres_password
ALPHA_VANTAGE_API_KEY=your_api_key_here
```

**Optional (for AI features):**
```env
OPENAI_API_KEY=your_openai_key_here
```

## 🎯 Running the Server

### Development Mode (with auto-reload)
```bash
npm run dev
```

### Production Mode
```bash
npm start
```

You should see:
```
🚀 Starting AI Stock Screener Backend...
📊 Connecting to database...
✅ Database ready
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 Server running on port 3000
📡 Health check: http://localhost:3000/health
🔍 API docs: http://localhost:3000/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 📡 API Endpoints

### 1. Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-09T10:30:00.000Z",
  "uptime": 120.5
}
```

### 2. Fetch Stock Data
Fetch stock fundamentals from Alpha Vantage and store in database.

```http
POST /stocks/fetch
Content-Type: application/json

{
  "ticker": "TCS"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Stock data fetched and stored successfully",
  "data": {
    "ticker": "TCS",
    "companyName": "Tata Consultancy Services",
    "sector": "Technology",
    "peRatio": 28.5,
    "marketCap": 1200000000000
  }
}
```

### 3. List All Stocks
Get all stocks with their fundamentals.

```http
GET /stocks?limit=50&offset=0&sector=Technology
```

**Response:**
```json
{
  "success": true,
  "count": 50,
  "data": [
    {
      "ticker": "TCS",
      "companyName": "Tata Consultancy Services",
      "sector": "Technology",
      "peRatio": 28.5,
      "marketCap": 1200000000000
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "hasMore": true
  }
}
```

### 4. Get Stock by Ticker
Get details of a specific stock.

```http
GET /stocks/TCS
```

**Response:**
```json
{
  "success": true,
  "data": {
    "ticker": "TCS",
    "companyName": "Tata Consultancy Services",
    "sector": "Technology",
    "peRatio": 28.5,
    "marketCap": 1200000000000
  }
}
```

### 5. Natural Language Query (AI Feature)
Query stocks using natural language.

```http
POST /stocks/query
Content-Type: application/json

{
  "query": "Show me stocks with PE ratio less than 15 and market cap above 1000 crores"
}
```

**Response:**
```json
{
  "success": true,
  "query": "Show me stocks with PE ratio less than 15...",
  "filters": [
    {
      "field": "pe_ratio",
      "operator": "<",
      "value": 15
    },
    {
      "field": "market_cap",
      "operator": ">",
      "value": 10000000000
    }
  ],
  "count": 12,
  "data": [...]
}
```

## 🗄️ Database Schema

### Symbols Table
```sql
CREATE TABLE symbols (
  id SERIAL PRIMARY KEY,
  ticker VARCHAR(20) UNIQUE NOT NULL,
  exchange VARCHAR(50),
  company_name VARCHAR(255),
  sector VARCHAR(100),
  industry VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Fundamentals Table
```sql
CREATE TABLE fundamentals (
  id SERIAL PRIMARY KEY,
  symbol_id INTEGER REFERENCES symbols(id) ON DELETE CASCADE,
  pe_ratio DECIMAL(10, 2),
  market_cap BIGINT,
  eps DECIMAL(10, 2),
  debt_to_equity DECIMAL(10, 2),
  promoter_holding DECIMAL(5, 2),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(symbol_id)
);
```

## 🧪 Testing the APIs

### Using cURL

**1. Fetch TCS stock data:**
```bash
curl -X POST http://localhost:3000/stocks/fetch \
  -H "Content-Type: application/json" \
  -d '{"ticker": "TCS"}'
```

**2. Query stocks:**
```bash
curl -X POST http://localhost:3000/stocks/query \
  -H "Content-Type: application/json" \
  -d '{"query": "Show stocks with PE ratio less than 15"}'
```

### Using Postman

1. Import the collection (create one from the examples above)
2. Set base URL: `http://localhost:3000`
3. Test each endpoint

## 🔧 Project Structure

```
backend/
├── server.js                 # Entry point (starts server)
├── app.js                    # Express app configuration
├── database.js               # PostgreSQL connection pool
├── llm.js                    # LLM query parser
├── routes/
│   └── stocks.routes.js      # API route definitions
├── controllers/
│   └── stocks.controller.js  # Request handlers
├── services/
│   └── marketData.service.js # Alpha Vantage integration
├── package.json              # Dependencies
├── .env.example              # Environment variables template
└── README.md                 # Documentation
```

## 🎓 How It Works

### Architecture Overview

```
Flutter App → Express API → LLM Parser → SQL Builder → PostgreSQL
                    ↓
              Alpha Vantage API
```

### Query Flow Example

**User Input:** "Show stocks with PE < 15"

1. **Flutter app** sends POST to `/stocks/query`
2. **Controller** receives request
3. **LLM Parser** converts to DSL:
   ```json
   {
     "filters": [
       {"field": "pe_ratio", "operator": "<", "value": 15}
     ]
   }
   ```
4. **SQL Builder** converts DSL to safe SQL:
   ```sql
   SELECT * FROM symbols s
   JOIN fundamentals f ON s.id = f.symbol_id
   WHERE f.pe_ratio < $1
   ```
5. **PostgreSQL** executes with params: `[15]`
6. **Response** sent back to Flutter

### Security Features

- ✅ **Parameterized Queries**: Prevents SQL injection
- ✅ **DSL Validation**: LLM can't execute arbitrary SQL
- ✅ **Field Whitelisting**: Only approved fields can be queried
- ✅ **Operator Whitelisting**: Only safe operators allowed
- ✅ **Helmet.js**: Security headers
- ✅ **CORS**: Controlled cross-origin access

## 🚨 Troubleshooting

### Database Connection Error
```
❌ Failed to initialize database: connect ECONNREFUSED
```

**Solution:**
- Ensure PostgreSQL is running: `pg_ctl status`
- Check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD in `.env`
- Verify database exists: `psql -U postgres -l`

### Alpha Vantage Rate Limit
```
API rate limit exceeded. Please try again later.
```

**Solution:**
- Free tier: 5 calls/minute, 500/day
- Wait before retrying
- Consider upgrading or using mock data

### Port Already in Use
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solution:**
```bash
# Find process using port 3000
netstat -ano | findstr :3000  # Windows
lsof -i :3000                 # Linux/Mac

# Kill the process or change PORT in .env
```

## 📚 Learning Resources

### Concepts Explained in Code

Each file contains detailed comments explaining:
- **Why** design decisions were made
- **How** each component works
- **What** happens at runtime
- **When** to use different patterns

### Key Concepts Covered

1. **RESTful API Design**: Proper HTTP methods, status codes, response formats
2. **Database Pooling**: Connection management for performance
3. **Transactions**: ACID properties for data consistency
4. **Error Handling**: Try-catch, async/await, graceful degradation
5. **Security**: SQL injection prevention, input validation
6. **Middleware**: Request pre-processing pipeline
7. **MVC Architecture**: Separation of concerns
8. **LLM Integration**: Prompt engineering, response parsing

## 🔮 Next Steps (Sprint 3+)

- [ ] Add authentication (JWT)
- [ ] Implement caching (Redis)
- [ ] Add rate limiting per user
- [ ] Historical data storage
- [ ] Backtesting endpoints
- [ ] WebSocket for real-time prices
- [ ] Admin dashboard
- [ ] Automated tests (Jest)
- [ ] Docker containerization
- [ ] CI/CD pipeline

## 📄 License

MIT

## 👨‍💻 Author

Built as an educational project for B.Tech students learning backend development.

---

**Happy Coding! 🚀**

For questions or issues, check the code comments or create an issue on GitHub.
