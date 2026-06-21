const express = require('express');
const { validateNegotiateRequest } = require('../middleware/validate');
const { generateBanter, providerStatus } = require('../services/negotiate_service');
const { createNegotiateRateLimiter } = require('../middleware/rate_limiter');

const router = express.Router();
const rateLimiter = createNegotiateRateLimiter();

// GET /api/negotiate/status — reports whether a live LLM is configured (no model call),
// so the client can show an accurate "live vs offline" indicator before any banter.
router.get('/status', (_req, res) => {
  res.status(200).json({ ok: true, ...providerStatus() });
});

// POST /api/negotiate — returns one in-character buyer banter line (MKT-R3). The
// deterministic haggle engine in the client owns the numbers; this only adds flavour
// text, and falls back to fallback:true when no LLM is configured or a call fails.
router.post('/', rateLimiter, async (req, res, next) => {
  try {
    const body = validateNegotiateRequest(req.body);
    const response = await generateBanter(body);
    res.status(200).json(response);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
