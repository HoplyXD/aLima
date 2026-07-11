const express = require('express');
const { validateMuseumRecordRequest } = require('../middleware/validate');
const { recordDiscovery, listRecords, getRecord } = require('../services/museum_service');
const { createMuseumRateLimiter } = require('../middleware/rate_limiter');

const router = express.Router();
const rateLimiter = createMuseumRateLimiter();

// POST /api/portal/museum — record a Gold find or Master Artifact discovery.
// Idempotent per player_id:record_id; always completes via deterministic
// fallback when the upstream Portal is unreachable (MUS-R2, §4-O).
router.post('/', rateLimiter, async (req, res, next) => {
  try {
    const body = validateMuseumRecordRequest(req.body);
    const result = await recordDiscovery(body);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

// GET /api/portal/museum?player_id=... — list a player's museum records.
// Hydrates from the Portal when reachable, from the disk cache otherwise
// (PORT-R6 retrieval, MUS-R3 offline mirror).
router.get('/', rateLimiter, async (req, res, next) => {
  try {
    const playerId = req.query.player_id;
    if (typeof playerId !== 'string' || playerId.length === 0) {
      return res.status(400).json({ ok: false, error: "'player_id' query param is required" });
    }
    const result = await listRecords(playerId);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

// GET /api/portal/museum/:entry_id?player_id=... — one record by entry id.
// 404 when neither the Portal nor the cache holds it.
router.get('/:entry_id', rateLimiter, async (req, res, next) => {
  try {
    const playerId = req.query.player_id;
    if (typeof playerId !== 'string' || playerId.length === 0) {
      return res.status(400).json({ ok: false, error: "'player_id' query param is required" });
    }
    const record = await getRecord(playerId, req.params.entry_id);
    if (!record) {
      return res.status(404).json({ ok: false, error: 'museum record not found' });
    }
    res.status(200).json(record);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
