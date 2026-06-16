const express = require('express');
const { validatePortalRequest } = require('../middleware/validate');
const { discover } = require('../services/portal_service');
const { createPortalRateLimiter } = require('../middleware/rate_limiter');

const router = express.Router();
const rateLimiter = createPortalRateLimiter();

router.post('/discovery', rateLimiter, async (req, res, next) => {
  try {
    const body = validatePortalRequest(req.body);
    const result = await discover(body);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
