const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const healthMonitor = require("./services/healthMonitor.service");
const backgroundEvaluator = require("./services/backgroundEvaluator.service");
const authService = require("./services/auth.service");
const { authenticateOptional } = require("./middleware/auth.middleware");
const logger = require("./utils/logger");
const app = express();

// Required when app is behind a reverse proxy/load balancer (Render, Nginx, etc.).
app.set("trust proxy", 1);

const allowedOrigins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

if (process.env.NODE_ENV === "production" && allowedOrigins.length === 0) {
  logger.warn(
    logger.LOG_CATEGORIES.SYSTEM,
    "CORS_ORIGINS is empty in production; browser origins will be rejected"
  );
}

// Security middleware
app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) {
        return callback(null, true);
      }
      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      if (process.env.NODE_ENV !== "production" && allowedOrigins.length === 0) {
        return callback(null, true);
      }
      const error = new Error("CORS origin not allowed");
      error.statusCode = 403;
      return callback(error);
    },
    credentials: true,
  })
);
app.use(express.json({ limit: process.env.MAX_REQUEST_SIZE || '1mb' }));
app.use(express.urlencoded({ extended: true, limit: process.env.MAX_REQUEST_SIZE || '1mb' }));
app.use((req, res, next) => {
  const timeoutMs = parseInt(process.env.REQUEST_TIMEOUT_MS || "30000", 10);
  req.setTimeout(timeoutMs);
  res.setTimeout(timeoutMs);
  next();
});
app.use(authenticateOptional);

const disableRateLimit = process.env.DISABLE_RATE_LIMIT === "true";
const rateLimitWindowMs = parseInt(process.env.RATE_LIMIT_WINDOW_MS || "900000", 10);
const rateLimitMaxRequests = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || "3000", 10);

// Rate limiting
const limiter = rateLimit({
  windowMs: rateLimitWindowMs,
  max: rateLimitMaxRequests,
  message: {
    status: 'error',
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Request limit exceeded. Please try again later.'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.path === "/health" || req.path === "/health/detailed",
});

// Apply rate limiting to all routes unless explicitly disabled for controlled load tests.
if (!disableRateLimit) {
  app.use(limiter);
} else {
  logger.warn(logger.LOG_CATEGORIES.SYSTEM, "Rate limiting disabled via DISABLE_RATE_LIMIT");
}

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info(logger.LOG_CATEGORIES.API, `${req.method} ${req.path}`, {
      status: res.statusCode,
      duration_ms: duration
    });
  });
  next();
});

// Routes
app.use("/stocks", require("./routes/stocks.routes"));
app.use("/", require("./routes/screener"));
app.use("/api", require("./routes/market.routes"));
app.use("/", require("./routes/health.routes"));
app.use("/api/advisory", require("./routes/advisory.routes"));
app.use("/api/insights", require("./routes/insights.routes"));
app.use("/api/portfolio", require("./routes/portfolio.routes"));
app.use("/api/watchlist", require("./routes/watchlist.routes")); // Watchlist
app.use("/api/alerts", require("./routes/alerts.routes"));
app.use("/api/screeners", require("./routes/screeners.routes")); // NEW: Saved Screeners
app.use("/api/suggestions", require("./routes/suggestions.routes")); // Query suggestions
app.use("/api/users", require("./routes/users.routes"));
app.use("/api/admin", require("./routes/admin.routes"));

// Start health monitoring
healthMonitor.startPeriodicMonitoring(60);

authService.ensureAuthSchema().catch((error) => {
  logger.error(logger.LOG_CATEGORIES.SYSTEM, "Auth schema initialization failed", {
    error: error.message,
  });
});

// Start background evaluation (every 1 hour by default)
// Can be configured via EVALUATION_INTERVAL_MS environment variable
backgroundEvaluator.start();

// Global error handler
app.use((err, req, res, next) => {
  logger.error(logger.LOG_CATEGORIES.SYSTEM, 'Unhandled error', { error: err.message });
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    status: 'error',
    timestamp: new Date().toISOString(),
    error: {
      code: statusCode === 403 ? 'FORBIDDEN' : 'INTERNAL_SERVER_ERROR',
      message: statusCode === 403 ? err.message : 'An unexpected error occurred',
      details: process.env.NODE_ENV === 'development' ? err.message : undefined
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    timestamp: new Date().toISOString(),
    error: {
      code: 'ENDPOINT_NOT_FOUND',
      message: 'The requested endpoint does not exist',
      path: req.path
    }
  });
});

module.exports = app;
