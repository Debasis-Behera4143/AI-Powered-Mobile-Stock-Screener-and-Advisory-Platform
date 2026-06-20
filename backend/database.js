require("dotenv").config();
const { Pool } = require("pg");

const sslEnabled =
  process.env.DB_SSL === "true" ||
  process.env.PGSSLMODE === "require" ||
  !!process.env.DATABASE_URL;

const basePoolConfig = process.env.DATABASE_URL
  ? {
      connectionString: process.env.DATABASE_URL,
    }
  : {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
    };

const poolMax = parseInt(process.env.DB_POOL_MAX || "50", 10);
const poolIdleTimeoutMs = parseInt(process.env.DB_POOL_IDLE_TIMEOUT_MS || "30000", 10);
const poolConnectionTimeoutMs = parseInt(process.env.DB_POOL_CONNECTION_TIMEOUT_MS || "5000", 10);

const rejectUnauthorized = process.env.NODE_ENV === "production"
  ? process.env.DB_SSL_REJECT_UNAUTHORIZED !== "false"
  : false;

const pool = new Pool({
  ...basePoolConfig,
  ssl: sslEnabled ? { rejectUnauthorized } : false,
  max: poolMax,
  idleTimeoutMillis: poolIdleTimeoutMs,
  connectionTimeoutMillis: poolConnectionTimeoutMs,
});

// Handle pool errors to prevent app crashes
pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err);
});

// Test connection on startup
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('[DATABASE] Connection failed:', err.message);
  } else {
    console.log('[DATABASE] Connection established successfully');
  }
});

module.exports = pool;
