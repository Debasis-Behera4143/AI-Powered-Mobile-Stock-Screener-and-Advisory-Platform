/**
 * Users/Auth Routes
 * Backend-issued sessions with email OTP verification and Google ID-token login.
 */

const express = require("express");
const rateLimit = require("express-rate-limit");
const { body, validationResult } = require("express-validator");
const authService = require("../services/auth.service");

const router = express.Router();

const authLimiter = rateLimit({
  windowMs: parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS || "900000", 10),
  max: parseInt(process.env.AUTH_RATE_LIMIT_MAX_REQUESTS || "10", 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: "Too many authentication attempts. Please try again later.",
  },
  keyGenerator: (req) => {
    const email = String(req.body?.email || "").trim().toLowerCase();
    return email || req.ip;
  },
});

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      errors: errors.array(),
    });
  }
  next();
};

const asyncRoute = (handler) => async (req, res) => {
  try {
    await handler(req, res);
  } catch (error) {
    const statusCode = error.statusCode || 500;
    res.status(statusCode).json({
      success: false,
      error: statusCode === 500 ? "Authentication service error" : error.message,
      details: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

router.post(
  "/request-otp",
  authLimiter,
  [
    body("email").isEmail().withMessage("Valid email is required"),
    body("purpose")
      .optional()
      .isIn(["register"])
      .withMessage("Unsupported OTP purpose"),
  ],
  validate,
  asyncRoute(async (req, res) => {
    const email = String(req.body.email || "").trim().toLowerCase();
    const purpose = req.body.purpose || "register";
    const result = await authService.issueOtp(email, purpose);

    res.status(200).json({
      success: true,
      message: "Verification code sent",
      expiresAt: result.expiresAt,
      devOtp:
        process.env.NODE_ENV !== "production" && process.env.AUTH_DEV_OTP === "true"
          ? result.otp
          : undefined,
    });
  })
);

router.post(
  "/register",
  authLimiter,
  [
    body("email").isEmail().withMessage("Valid email is required"),
    body("name")
      .isString()
      .trim()
      .isLength({ min: 2, max: 255 })
      .withMessage("Name must be between 2 and 255 characters"),
    body("password")
      .isStrongPassword({
        minLength: 8,
        minLowercase: 1,
        minUppercase: 1,
        minNumbers: 1,
        minSymbols: 1,
      })
      .withMessage(
        "Password must be 8+ characters with upper, lower, number, and symbol"
      ),
    body("otp").isLength({ min: 6, max: 6 }).isNumeric(),
  ],
  validate,
  asyncRoute(async (req, res) => {
    const result = await authService.registerWithOtp({
      email: String(req.body.email || "").trim().toLowerCase(),
      name: String(req.body.name || "").trim(),
      password: String(req.body.password || ""),
      otp: String(req.body.otp || ""),
    });

    res.status(201).json({
      success: true,
      data: result,
    });
  })
);

router.post(
  "/login",
  authLimiter,
  [
    body("email").isEmail().withMessage("Valid email is required"),
    body("password").isString().isLength({ min: 1 }),
  ],
  validate,
  asyncRoute(async (req, res) => {
    const result = await authService.loginWithPassword({
      email: String(req.body.email || "").trim().toLowerCase(),
      password: String(req.body.password || ""),
    });

    res.status(200).json({
      success: true,
      data: result,
    });
  })
);

router.post(
  "/google",
  authLimiter,
  [body("idToken").isString().isLength({ min: 20 })],
  validate,
  asyncRoute(async (req, res) => {
    const result = await authService.loginWithGoogle({
      idToken: String(req.body.idToken || ""),
    });

    res.status(200).json({
      success: true,
      data: result,
    });
  })
);

module.exports = router;
