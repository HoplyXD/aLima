const express = require('express');
const { validateMuseumRecordRequest } = require('../middleware/validate');
const { recordDiscovery, listRecords, getRecord } = require('../services/museum_registry');

const router = express.Router();

router.post('/', async (req, res, next) => {
  try {
    const body = validateMuseumRecordRequest(req.body);
    const result = await recordDiscovery(
      body.record_id,
      body.player_id,
      body.rarity,
      body.display_name
    );
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

router.get('/', async (req, res, next) => {
  try {
    const playerId = req.query.player_id;
    if (typeof playerId !== 'string' || playerId.length === 0) {
      return res.status(400).json({ ok: false, error: "'player_id' query param is required" });
    }
    const entries = await listRecords(playerId);
    res.status(200).json({ ok: true, entries });
  } catch (err) {
    next(err);
  }
});

router.get('/:entry_id', async (req, res, next) => {
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
