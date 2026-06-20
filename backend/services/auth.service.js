const crypto = require("crypto");
const http = require("http");
const https = require("https");
const nodemailer = require("nodemailer");
const db = require("../database");

const OTP_TTL_MINUTES = parseInt(process.env.OTP_TTL_MINUTES || "10", 10);
const JWT_TTL_SECONDS = parseInt(process.env.JWT_TTL_SECONDS || "86400", 10);
const JWT_SECRET =
  process.env.JWT_SECRET ||
  (process.env.NODE_ENV === "production"
    ? ""
    : "development-only-jwt-secret-change-before-production");
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || "";
const OTP_DELIVERY_WEBHOOK_URL = process.env.OTP_DELIVERY_WEBHOOK_URL || "";

// SMTP Settings for Direct Email OTP Delivery
const SMTP_HOST = process.env.SMTP_HOST || "";
const SMTP_PORT = parseInt(process.env.SMTP_PORT || "587", 10);
const SMTP_SECURE = process.env.SMTP_SECURE === "true";
const SMTP_USER = process.env.SMTP_USER || "";
const SMTP_PASS = process.env.SMTP_PASS || "";
const SMTP_FROM = process.env.SMTP_FROM || "EquiScan Alerts <no-reply@equiscan.com>";

let mailTransporter = null;
function getMailTransporter() {
  if (mailTransporter) return mailTransporter;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) return null;
  mailTransporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_SECURE,
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASS,
    },
  });
  return mailTransporter;
}

let authSchemaReady;
let googleCertCache = { expiresAt: 0, certs: {} };

function base64UrlEncode(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function base64UrlDecode(input) {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/");
  return Buffer.from(padded, "base64");
}

function hash(value, salt = crypto.randomBytes(16).toString("hex")) {
  const digest = crypto
    .pbkdf2Sync(value, salt, 120000, 32, "sha256")
    .toString("hex");
  return `${salt}:${digest}`;
}

function verifyHash(value, storedHash) {
  if (!storedHash || !storedHash.includes(":")) return false;
  const [salt, digest] = storedHash.split(":");
  const candidate = hash(value, salt).split(":")[1];
  if (candidate.length !== digest.length) return false;
  return crypto.timingSafeEqual(Buffer.from(candidate), Buffer.from(digest));
}

function signJwt(payload) {
  if (JWT_SECRET.length < 32) {
    throw new Error("JWT_SECRET must be set to at least 32 characters");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "HS256", typ: "JWT" };
  const body = {
    ...payload,
    iat: now,
    exp: now + JWT_TTL_SECONDS,
  };
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(body)
  )}`;
  const signature = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(unsigned)
    .digest("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${unsigned}.${signature}`;
}

function verifyJwt(token) {
  try {
    if (!JWT_SECRET || !token) return null;
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const [header, body, signature] = parts;
    const expected = crypto
      .createHmac("sha256", JWT_SECRET)
      .update(`${header}.${body}`)
      .digest("base64")
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

    if (
      expected.length !== signature.length ||
      !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature))
    ) {
      return null;
    }

    const payload = JSON.parse(base64UrlDecode(body).toString("utf8"));
    if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
    if (!payload.sub || !Number.isInteger(parseInt(payload.sub, 10))) return null;
    return payload;
  } catch (_) {
    return null;
  }
}

async function ensureAuthSchema() {
  if (!authSchemaReady) {
    authSchemaReady = (async () => {
      await db.query(`
        ALTER TABLE users
          ADD COLUMN IF NOT EXISTS password_hash TEXT,
          ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(30) DEFAULT 'password',
          ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255),
          ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false,
          ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP
      `);
      await db.query(`
        CREATE TABLE IF NOT EXISTS auth_otps (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) NOT NULL,
          purpose VARCHAR(30) NOT NULL,
          otp_hash TEXT NOT NULL,
          consumed BOOLEAN DEFAULT false,
          expires_at TIMESTAMP NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      await db.query(
        "CREATE INDEX IF NOT EXISTS idx_auth_otps_email_purpose ON auth_otps(email, purpose)"
      );
      await db.query(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_sub ON users(google_sub) WHERE google_sub IS NOT NULL"
      );
    })();
  }
  return authSchemaReady;
}

async function issueOtp(email, purpose = "register") {
  await ensureAuthSchema();
  const normalizedEmail = email.trim().toLowerCase();
  const otp = crypto.randomInt(100000, 1000000).toString();
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

  await db.query(
    `UPDATE auth_otps
     SET consumed = true
     WHERE email = $1 AND purpose = $2 AND consumed = false`,
    [normalizedEmail, purpose]
  );
  await db.query(
    `INSERT INTO auth_otps (email, purpose, otp_hash, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [normalizedEmail, purpose, hash(otp), expiresAt]
  );
  await deliverOtp({ email: normalizedEmail, otp, purpose, expiresAt });

  return {
    otp,
    expiresAt,
  };
}

async function consumeOtp(email, otp, purpose = "register") {
  await ensureAuthSchema();
  const normalizedEmail = email.trim().toLowerCase();
  const result = await db.query(
    `SELECT id, otp_hash
     FROM auth_otps
     WHERE email = $1
       AND purpose = $2
       AND consumed = false
       AND expires_at > NOW()
     ORDER BY created_at DESC
     LIMIT 1`,
    [normalizedEmail, purpose]
  );

  if (result.rowCount === 0 || !verifyHash(otp, result.rows[0].otp_hash)) {
    return false;
  }

  await db.query("UPDATE auth_otps SET consumed = true WHERE id = $1", [
    result.rows[0].id,
  ]);
  return true;
}

async function findOrCreateUser({ email, name, password, googleSub }) {
  await ensureAuthSchema();
  const normalizedEmail = email.trim().toLowerCase();
  const existing = await db.query(
    `SELECT id, email, name, password_hash, auth_provider, email_verified
     FROM users
     WHERE LOWER(email) = LOWER($1)
     LIMIT 1`,
    [normalizedEmail]
  );

  if (existing.rowCount > 0) {
    const user = existing.rows[0];
    if (googleSub) {
      await db.query(
        `UPDATE users
         SET google_sub = COALESCE(google_sub, $2),
             auth_provider = 'google',
             email_verified = true,
             last_login_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [user.id, googleSub]
      );
    }
    return user;
  }

  const created = await db.query(
    `INSERT INTO users (email, name, password_hash, auth_provider, google_sub, email_verified, last_login_at)
     VALUES ($1, $2, $3, $4, $5, true, NOW())
     RETURNING id, email, name, password_hash, auth_provider, email_verified`,
    [
      normalizedEmail,
      name || null,
      password ? hash(password) : null,
      googleSub ? "google" : "password",
      googleSub || null,
    ]
  );
  return created.rows[0];
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    authProvider: user.auth_provider,
    emailVerified: user.email_verified,
  };
}

async function registerWithOtp({ email, name, password, otp }) {
  const ok = await consumeOtp(email, otp, "register");
  if (!ok) {
    const err = new Error("Invalid or expired verification code");
    err.statusCode = 401;
    throw err;
  }

  await ensureAuthSchema();
  const existing = await db.query(
    `SELECT id, password_hash
     FROM users
     WHERE LOWER(email) = LOWER($1)
     LIMIT 1`,
    [email.trim().toLowerCase()]
  );
  if (existing.rowCount > 0 && existing.rows[0].password_hash) {
    const err = new Error("An account with this email already exists");
    err.statusCode = 409;
    throw err;
  }

  const user = await findOrCreateUser({ email, name, password });
  if (existing.rowCount > 0 && !existing.rows[0].password_hash) {
    await db.query(
      `UPDATE users
       SET password_hash = $2,
           auth_provider = 'password',
           email_verified = true,
           last_login_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [user.id, hash(password)]
    );
    user.password_hash = true;
    user.email_verified = true;
  }
  const token = signJwt({ sub: String(user.id), email: user.email });
  return { token, user: publicUser(user) };
}

async function loginWithPassword({ email, password }) {
  await ensureAuthSchema();
  const normalizedEmail = email.trim().toLowerCase();
  const result = await db.query(
    `SELECT id, email, name, password_hash, auth_provider, email_verified
     FROM users
     WHERE LOWER(email) = LOWER($1)
     LIMIT 1`,
    [normalizedEmail]
  );

  if (
    result.rowCount === 0 ||
    !result.rows[0].password_hash ||
    !verifyHash(password, result.rows[0].password_hash)
  ) {
    const err = new Error("Invalid email or password");
    err.statusCode = 401;
    throw err;
  }

  await db.query("UPDATE users SET last_login_at = NOW() WHERE id = $1", [
    result.rows[0].id,
  ]);
  const token = signJwt({
    sub: String(result.rows[0].id),
    email: result.rows[0].email,
  });
  return { token, user: publicUser(result.rows[0]) };
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          try {
            resolve({ headers: res.headers, json: JSON.parse(data) });
          } catch (error) {
            reject(error);
          }
        });
      })
      .on("error", reject);
  });
}

function postJson(url, payload) {
  return new Promise((resolve, reject) => {
    const target = new URL(url);
    if (process.env.NODE_ENV === "production" && target.protocol !== "https:") {
      return reject(new Error("OTP delivery webhook must use HTTPS in production"));
    }
    const client = target.protocol === "https:" ? https : http;
    const body = JSON.stringify(payload);
    const req = client.request(
      target,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        res.resume();
        res.on("end", () => {
          if (res.statusCode >= 200 && res.statusCode < 300) return resolve();
          reject(new Error(`OTP delivery webhook failed with ${res.statusCode}`));
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function deliverOtp({ email, otp, purpose, expiresAt }) {
  // Option A: Direct SMTP Email delivery
  const transporter = getMailTransporter();
  if (transporter) {
    try {
      const info = await transporter.sendMail({
        from: SMTP_FROM,
        to: email,
        subject: "Your EquiScan Verification Code",
        html: `
          <div style="font-family: sans-serif; padding: 24px; max-width: 600px; margin: auto; background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px;">
            <h2 style="color: #6366f1; font-size: 24px; margin-bottom: 8px;">EquiScan Verification</h2>
            <p style="color: #334155; font-size: 16px; margin-bottom: 24px;">Please use the following 6-digit One-Time Password (OTP) to complete your account registration. This code expires in 10 minutes.</p>
            <div style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #0f172a; background-color: #ffffff; padding: 16px; border-radius: 8px; text-align: center; border: 1px dashed #cbd5e1; margin-bottom: 24px;">
              ${otp}
            </div>
            <p style="color: #64748b; font-size: 14px;">If you did not request this verification, please ignore this email.</p>
          </div>
        `,
      });
      console.log(`[Auth] Real SMTP email sent to ${email} (messageId: ${info.messageId})`);
      return;
    } catch (err) {
      console.error("[Auth] Direct SMTP email delivery failed:", err.message);
      if (!OTP_DELIVERY_WEBHOOK_URL) throw err;
    }
  }

  // Option B: Webhook OTP delivery fallback
  if (OTP_DELIVERY_WEBHOOK_URL) {
    await postJson(OTP_DELIVERY_WEBHOOK_URL, {
      email,
      otp,
      purpose,
      expiresAt,
      subject: "Your EquiScan verification code",
    });
    return;
  }

  if (process.env.NODE_ENV === "production") {
    throw new Error("OTP delivery is not configured. Set SMTP_* or OTP_DELIVERY_WEBHOOK_URL variables.");
  }

  console.log(`[Auth] OTP for ${email}: ${otp}`);
}

async function getGoogleCerts() {
  if (googleCertCache.expiresAt > Date.now()) return googleCertCache.certs;
  const { headers, json } = await fetchJson(
    "https://www.googleapis.com/oauth2/v1/certs"
  );
  const maxAge = /max-age=(\d+)/.exec(headers["cache-control"] || "");
  googleCertCache = {
    expiresAt: Date.now() + (maxAge ? parseInt(maxAge[1], 10) : 3600) * 1000,
    certs: json,
  };
  return googleCertCache.certs;
}

async function verifyGoogleIdToken(idToken) {
  if (!GOOGLE_CLIENT_ID) {
    throw new Error("GOOGLE_CLIENT_ID is not configured");
  }

  const [encodedHeader, encodedPayload, signature] = idToken.split(".");
  if (!encodedHeader || !encodedPayload || !signature) {
    throw new Error("Invalid Google ID token");
  }

  const header = JSON.parse(base64UrlDecode(encodedHeader).toString("utf8"));
  const payload = JSON.parse(base64UrlDecode(encodedPayload).toString("utf8"));
  const certs = await getGoogleCerts();
  const cert = certs[header.kid];
  if (!cert) throw new Error("Google signing certificate not found");

  const verifier = crypto.createVerify("RSA-SHA256");
  verifier.update(`${encodedHeader}.${encodedPayload}`);
  verifier.end();
  const valid = verifier.verify(cert, base64UrlDecode(signature));

  if (!valid) throw new Error("Invalid Google token signature");
  if (payload.aud !== GOOGLE_CLIENT_ID) throw new Error("Invalid Google audience");
  if (payload.exp < Math.floor(Date.now() / 1000)) {
    throw new Error("Google token expired");
  }
  if (!payload.email || payload.email_verified !== true) {
    throw new Error("Google account email is not verified");
  }

  return payload;
}

async function loginWithGoogle({ idToken }) {
  const googleUser = await verifyGoogleIdToken(idToken);
  const user = await findOrCreateUser({
    email: googleUser.email,
    name: googleUser.name,
    googleSub: googleUser.sub,
  });
  const token = signJwt({ sub: String(user.id), email: user.email });
  return { token, user: publicUser(user) };
}

module.exports = {
  ensureAuthSchema,
  issueOtp,
  registerWithOtp,
  loginWithPassword,
  loginWithGoogle,
  verifyJwt,
};
