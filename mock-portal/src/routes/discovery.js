const express = require('express');
const { validateDiscoveryRequest } = require('../middleware/validate');
const { getFactCard } = require('../services/fact_service');

const router = express.Router();

router.post('/', (req, res, next) => {
  try {
    const body = validateDiscoveryRequest(req.body);
    const result = getFactCard(body.fragment_id, body.player_id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
