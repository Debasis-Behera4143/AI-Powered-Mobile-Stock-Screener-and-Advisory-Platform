# 📘 PROJECT ARCHITECTURE GUIDE
# AI-Powered Stock Screener Backend
# For B.Tech Students

## 🎯 WHAT YOU BUILT

A production-ready RESTful API backend that:
- Fetches real stock market data from Alpha Vantage
- Stores it in PostgreSQL database
- Allows natural language queries using LLM (AI)
- Serves data to a Flutter mobile app

## 🏗️ ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│                      FLUTTER MOBILE APP                      │
│                    (User Interface)                          │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTP Requests (JSON)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    EXPRESS.JS SERVER                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Routes (stocks.routes.js)                           │  │
│  │  • GET  /stocks       → List all stocks              │  │
│  │  • POST /stocks/fetch → Fetch from market            │  │
│  │  • POST /stocks/query → Natural language search      │  │
│  └──────────────────────────────────────────────────────┘  │
│                       │                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Controllers (stocks.controller.js)                  │  │
│  │  • Validate input                                    │  │
│  │  • Call services                                     │  │
│  │  • Format response                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                       │                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Services (marketData.service.js)                    │  │
│  │  • Fetch from Alpha Vantage                          │  │
│  │  • Parse API response                                │  │
│  │  • Transform data                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                       │                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  LLM Parser (llm.js)                                 │  │
│  │  • Convert "PE < 15" → {"field": "pe_ratio", ...}   │  │
│  │  • Validate filters                                  │  │
│  │  • Generate safe SQL                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                       │                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Database Layer (database.js)                        │  │
│  │  • Connection pool                                   │  │
│  │  • Query execution                                   │  │
│  │  • Transaction management                            │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼                           ▼
┌──────────────────┐      ┌─────────────────────┐
│   PostgreSQL     │      │   Alpha Vantage     │
│   Database       │      │   Market Data API   │
│                  │      │                     │
│ • symbols table  │      │ Real-time stock     │
│ • fundamentals   │      │ fundamentals        │
└──────────────────┘      └─────────────────────┘
```

## 📁 FILE STRUCTURE EXPLAINED

```
backend/
│
├── 📄 server.js                    ⭐ ENTRY POINT
│   └─ What: Starts the HTTP server
│   └─ Why: Separates server lifecycle from app logic
│   └─ Learn: Process management, graceful shutdown
│
├── 📄 app.js                       ⭐ EXPRESS APP
│   └─ What: Configures Express middleware and routes
│   └─ Why: Makes testing easier (no server needed)
│   └─ Learn: Middleware pipeline, error handling
│
├── 📄 database.js                  ⭐ DATABASE CONNECTION
│   └─ What: PostgreSQL connection pool
│   └─ Why: Reuse connections efficiently
│   └─ Learn: Connection pooling, transactions
│
├── 📄 llm.js                       ⭐ AI QUERY PARSER
│   └─ What: Converts natural language → structured JSON
│   └─ Why: Safe AI integration (no raw SQL from LLM)
│   └─ Learn: LLM prompting, DSL design, validation
│
├── 📁 routes/
│   └── 📄 stocks.routes.js         ⭐ API ROUTES
│       └─ What: Defines URL endpoints
│       └─ Why: Separation of concerns (routing ≠ logic)
│       └─ Learn: RESTful API design
│
├── 📁 controllers/
│   └── 📄 stocks.controller.js     ⭐ REQUEST HANDLERS
│       └─ What: Processes requests, calls services
│       └─ Why: Thin controllers, fat services
│       └─ Learn: MVC pattern, input validation
│
├── 📁 services/
│   └── 📄 marketData.service.js    ⭐ BUSINESS LOGIC
│       └─ What: Fetches data from Alpha Vantage
│       └─ Why: Reusable, testable, swappable
│       └─ Learn: Service layer pattern, API integration
│
├── 📄 .env.example                 ⭐ CONFIGURATION
│   └─ What: Template for environment variables
│   └─ Why: Security (no secrets in code)
│   └─ Learn: 12-factor app principles
│
├── 📄 schema.sql                   ⭐ DATABASE SCHEMA
│   └─ What: SQL to create tables and sample data
│   └─ Why: Version-controlled database structure
│   └─ Learn: SQL, database design
│
├── 📄 package.json                 ⭐ DEPENDENCIES
│   └─ What: Lists required npm packages
│   └─ Why: Reproducible builds
│   └─ Learn: npm, semantic versioning
│
└── 📄 test-api.js                  ⭐ API TESTS
    └─ What: Automated tests for all endpoints
    └─ Why: Verify everything works
    └─ Learn: API testing, axios
```

## 🔄 REQUEST FLOW (DETAILED)

Let's trace what happens when Flutter app sends:
```
POST /stocks/query
Body: {"query": "Show stocks with PE ratio less than 15"}
```

### Step 1: HTTP Request Arrives
```
Flutter App → server.js (listening on port 3000)
```

### Step 2: Middleware Pipeline (app.js)
```
Request passes through:
1. helmet()         → Adds security headers
2. cors()           → Checks if origin is allowed
3. morgan()         → Logs the request
4. express.json()   → Parses JSON body
```

### Step 3: Route Matching (stocks.routes.js)
```
Router finds: POST /stocks/query
Routes to: stocksController.queryStocks()
```

### Step 4: Controller Processing (stocks.controller.js)
```javascript
queryStocks() {
  1. Extract query from req.body
  2. Validate input (is query present?)
  3. Call LLM parser
  4. Convert DSL to SQL
  5. Execute query
  6. Format response
  7. Send JSON back
}
```

### Step 5: LLM Parsing (llm.js)
```javascript
parseQuery("Show stocks with PE ratio less than 15") {
  1. Build prompt for OpenAI
  2. Send to GPT-4
  3. Receive: {"filters": [{"field": "pe_ratio", "operator": "<", "value": 15}]}
  4. Validate filters (is pe_ratio a valid field?)
  5. Return DSL
}
```

### Step 6: SQL Generation (llm.js)
```javascript
dslToSQL(queryDSL) {
  1. Map fields to database columns
  2. Build WHERE clauses
  3. Add parameters ($1, $2, etc.)
  4. Return: {
       sql: "SELECT ... WHERE f.pe_ratio < $1",
       params: [15]
     }
}
```

### Step 7: Database Query (database.js)
```javascript
query(sql, params) {
  1. Get connection from pool
  2. Execute: SELECT ... WHERE f.pe_ratio < $1 WITH [15]
  3. PostgreSQL returns matching rows
  4. Return result to controller
}
```

### Step 8: Response Sent
```
Controller → Express → Flutter App
JSON: {
  "success": true,
  "count": 5,
  "data": [...]
}
```

## 🔐 SECURITY FEATURES

### 1. SQL Injection Prevention
```javascript
// ❌ UNSAFE (vulnerable)
const sql = `SELECT * FROM stocks WHERE ticker = '${userInput}'`;
// Hacker sends: userInput = "'; DROP TABLE stocks; --"

// ✅ SAFE (parameterized)
const sql = `SELECT * FROM stocks WHERE ticker = $1`;
query(sql, [userInput]);
```

### 2. LLM Output Validation
```javascript
// ✅ LLM can only output these fields
const VALID_FIELDS = ['pe_ratio', 'market_cap', 'eps', ...];

// ✅ LLM can only use these operators
const VALID_OPERATORS = ['=', '<', '>', '<=', '>=', 'LIKE'];

// ✅ Every LLM response is validated
if (!VALID_FIELDS.includes(filter.field)) {
  throw new Error('Invalid field');
}
```

### 3. CORS Protection
```javascript
// Only allow requests from Flutter app
cors({
  origin: 'https://your-flutter-app.com'
});
```

## 💡 KEY CONCEPTS EXPLAINED

### 1. MVC Pattern (Model-View-Controller)
```
Model      = Database (PostgreSQL tables)
View       = JSON responses (for Flutter app)
Controller = stocks.controller.js
```

### 2. Connection Pooling
```
❌ Bad: Create new connection for each request
   Request 1 → Connect → Query → Disconnect
   Request 2 → Connect → Query → Disconnect
   (Slow! Each connection takes ~100ms)

✅ Good: Reuse connections from a pool
   Pool: [Conn1, Conn2, Conn3, ...]
   Request 1 → Borrow Conn1 → Query → Return Conn1
   Request 2 → Borrow Conn1 → Query → Return Conn1
   (Fast! No connection overhead)
```

### 3. Transactions (ACID)
```javascript
// All-or-nothing: Both succeed or both rollback
await client.query('BEGIN');
try {
  await client.query('INSERT INTO symbols ...');
  await client.query('INSERT INTO fundamentals ...');
  await client.query('COMMIT'); // ✅ Save both
} catch (error) {
  await client.query('ROLLBACK'); // ❌ Undo both
}
```

### 4. Async/Await
```javascript
// ❌ Old way (callback hell)
fetchData((data) => {
  saveData(data, () => {
    sendResponse(() => {
      // nested callbacks...
    });
  });
});

// ✅ Modern way (async/await)
const data = await fetchData();
await saveData(data);
await sendResponse();
```

## 🎓 LEARNING PROGRESSION

### Beginner (Week 1-2)
- [ ] Understand HTTP: GET, POST, status codes
- [ ] Learn JSON format
- [ ] Read server.js comments
- [ ] Run the server and test /health endpoint

### Intermediate (Week 3-4)
- [ ] Understand Express middleware
- [ ] Learn SQL basics (SELECT, JOIN, WHERE)
- [ ] Study routes → controllers → services flow
- [ ] Try modifying an endpoint

### Advanced (Week 5-6)
- [ ] Database transactions
- [ ] LLM integration and prompt engineering
- [ ] Error handling patterns
- [ ] Add authentication (JWT)

## 🚀 NEXT FEATURES TO BUILD

### Sprint 3: Authentication
```javascript
// Add JWT-based auth
POST /auth/register  → Create user
POST /auth/login     → Get JWT token
Headers: Authorization: Bearer <token>
```

### Sprint 4: Caching
```javascript
// Add Redis for faster queries
GET /stocks → Check Redis → If miss, query PostgreSQL → Cache result
```

### Sprint 5: Real-time Updates
```javascript
// Add WebSocket for live prices
WebSocket: wss://localhost:3000/live
```

## 📚 RECOMMENDED READING

1. **Node.js & Express**
   - MDN Web Docs: HTTP
   - Express.js Official Docs

2. **PostgreSQL**
   - PostgreSQL Tutorial
   - Database Design Principles

3. **API Design**
   - RESTful API Best Practices
   - HTTP Status Codes Guide

4. **LLM Integration**
   - OpenAI Cookbook
   - Prompt Engineering Guide

## ❓ FAQ

**Q: Why separate routes, controllers, and services?**
A: Separation of Concerns. Routes define URLs, controllers validate input, services contain business logic. Makes testing and maintenance easier.

**Q: Why use connection pooling instead of one connection?**
A: One connection = bottleneck. Pool allows concurrent requests. Like having multiple checkout counters in a store.

**Q: Why DSL instead of letting LLM write SQL directly?**
A: Security! LLM could hallucinate dangerous SQL like "DROP TABLE". DSL is a safe intermediate format we control.

**Q: What if Alpha Vantage API is down?**
A: We have fallback mock data. In production, use multiple data providers.

**Q: How to deploy this to production?**
A: Docker → AWS ECS/EC2 or Heroku. Add: environment variables, monitoring (DataDog), logging (Winston).

---

**Built with ❤️ for learning. Questions? Read the code comments!**
