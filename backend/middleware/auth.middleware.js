const authService = require("../services/auth.service");

function authenticateOptional(req, res, next) {
  const header = req.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(header);

  if (match) {
    const payload = authService.verifyJwt(match[1]);
    if (payload) {
      req.user = {
        id: parseInt(payload.sub, 10),
        email: payload.email,
      };
    }
  }

  next();
}

function authenticateRequired(req, res, next) {
  authenticateOptional(req, res, () => {
    if (!req.user?.id) {
      return res.status(401).json({
        success: false,
        error: "Authentication required",
      });
    }
    next();
  });
}

function requireMatchingUser(req, res, next) {
  const userId = req.params.userId || req.body.userId || req.query.userId;
  if (!req.user?.id || parseInt(userId, 10) !== req.user.id) {
    return res.status(403).json({
      success: false,
      error: "Authenticated user does not match requested user",
    });
  }
  next();
}

function requireAdmin(req, res, next) {
  const configuredAdminKey = process.env.ADMIN_API_KEY || "";
  const providedAdminKey = req.get("x-admin-api-key") || "";
  const adminUserIds = (process.env.ADMIN_USER_IDS || "")
    .split(",")
    .map((value) => parseInt(value.trim(), 10))
    .filter(Number.isInteger);

  if (configuredAdminKey.length >= 32 && providedAdminKey === configuredAdminKey) {
    return next();
  }

  if (req.user?.id && adminUserIds.includes(req.user.id)) {
    return next();
  }

  return res.status(403).json({
    success: false,
    error: "Admin access required",
  });
}

module.exports = {
  authenticateOptional,
  authenticateRequired,
  requireMatchingUser,
  requireAdmin,
};
