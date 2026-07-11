const fs = require('fs');
const config = require('../config');
const db = require('../db');

let museumRecords = null;

function loadMuseumRecords() {
  if (museumRecords) {
    return museumRecords;
  }
  if (!fs.existsSync(config.museumRecordsPath)) {
    museumRecords = {};
    return museumRecords;
  }
  const raw = fs.readFileSync(config.museumRecordsPath, 'utf8');
  museumRecords = JSON.parse(raw);
  return museumRecords;
}

function lookupFact(recordId) {
  const records = loadMuseumRecords();
  return records[recordId] || null;
}

function generateMuseumEntryId(recordId, playerId) {
  return `entry_${recordId}_${playerId}`;
}

function buildRecord(recordId, playerId, rarity, displayName) {
  const fact = lookupFact(recordId);
  const meta = fact && fact.artifact_meta ? fact.artifact_meta : {};

  const entryId = generateMuseumEntryId(recordId, playerId);
  return {
    ok: true,
    museum_entry_id: entryId,
    player_id: playerId,
    entry_id: entryId,
    record_id: recordId,
    record_type: rarity === 'master_artifact' ? 'assembled_artifact' : 'museum_discovery',
    rarity,
    display_name: displayName || recordId,
    fact_card:
      fact && fact.fact_card
        ? fact.fact_card
        : `MOCK record for ${displayName || recordId}. ` +
          'Verified provenance pending source review.',
    photo_ref: (fact && fact.photo_ref) || '',
    timeline_entry:
      (fact && fact.timeline_entry) ||
      'Provenance timeline pending source verification.',
    regional_story:
      (fact && fact.regional_story) ||
      'Regional story pending source verification.',
    character_memory_refs: (fact && fact.character_memory_refs) || [],
    artifact_meta: {
      name: meta.name || displayName || recordId,
      period: meta.period || 'pending verification',
      origin: meta.origin || 'Western Visayas (pending verification)',
    },
    created_at: new Date().toISOString(),
  };
}

async function recordDiscovery(recordId, playerId, rarity, displayName) {
  const record = buildRecord(recordId, playerId, rarity, displayName);
  await db.recordDiscovery(record);
  return record;
}

async function listRecords(playerId) {
  return db.listRecords(playerId);
}

async function getRecord(playerId, entryId) {
  return db.getRecord(playerId, entryId);
}

async function resetRegistry() {
  museumRecords = null;
  await db.resetRecords();
}

module.exports = {
  recordDiscovery,
  listRecords,
  getRecord,
  generateMuseumEntryId,
  resetRegistry,
};
