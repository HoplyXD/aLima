const rateLimit = require('express-rate-limit');

function createScanRateLimiter() {
  return rateLimit({
    windowMs: 60 * 1000,
    max: () => parseInt(process.env.RATE_LIMIT_SCAN || '30', 10),
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        ok: false,
        error: 'Too many scan requests, please try again later.',
      });
    },
  });
}

function createPortalRateLimiter() {
  return rateLimit({
    windowMs: 60 * 1000,
    max: () => parseInt(process.env.RATE_LIMIT_PORTAL || '10', 10),
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({
        ok: false,
        error: 'Too many portal requests, please try again later.',
      });
    },
  });
}

module.exports = {
  createScanRateLimiter,
  createPortalRateLimiter,
};
