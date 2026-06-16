const express = require('express');
const { validateScanRequest } = require('../middleware/validate');
const { getCachedResponse } = require('../services/scan_service');
const { createScanRateLimiter } = require('../middleware/rate_limiter');

const router = express.Router();
const rateLimiter = createScanRateLimiter();

router.post('/', rateLimiter, (req, res, next) => {
  try {
    const body = validateScanRequest(req.body);
    const response = getCachedResponse(body.template_id, body.request_id);
    res.status(200).json(response);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
