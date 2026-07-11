const fs = require('fs');
const path = require('path');
const config = require('../config');

let museumRecords = null;
let registry = {}; // player_id -> { entry_id -> record }

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

function getRegistryPath() {
  return config.museumRegistryPath;
}

function ensureRegistryDir() {
  const dir = path.dirname(getRegistryPath());
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function saveRegistry() {
  if (!config.museumRegistryPath) {
    return;
  }
  ensureRegistryDir();
  fs.writeFileSync(config.museumRegistryPath, JSON.stringify(registry, null, 2));
}

function loadRegistry() {
  if (!config.museumRegistryPath || !fs.existsSync(config.museumRegistryPath)) {
    registry = {};
    return;
  }
  try {
    const raw = fs.readFileSync(config.museumRegistryPath, 'utf8');
    registry = JSON.parse(raw);
  } catch (_err) {
    registry = {};
  }
}

function generateMuseumEntryId(recordId, playerId) {
  return `entry_${recordId}_${playerId}`;
}

function lookupFact(recordId) {
  const records = loadMuseumRecords();
  return records[recordId] || null;
}

function buildRecord(recordId, playerId, rarity, displayName) {
  const fact = lookupFact(recordId);
  const meta = fact && fact.artifact_meta ? fact.artifact_meta : {};

  return {
    ok: true,
    museum_entry_id: generateMuseumEntryId(recordId, playerId),
    record_id: recordId,
    record_type: rarity === 'master_artifact' ? 'assembled_artifact' : 'museum_discovery',
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
  };
}

function recordDiscovery(recordId, playerId, rarity, displayName) {
  if (!registry[playerId]) {
    registry[playerId] = {};
  }
  const entryId = generateMuseumEntryId(recordId, playerId);
  const record = buildRecord(recordId, playerId, rarity, displayName);
  registry[playerId][entryId] = record;
  saveRegistry();
  return record;
}

function listRecords(playerId) {
  if (!registry[playerId]) {
    return [];
  }
  const entries = Object.values(registry[playerId]);
  entries.sort((a, b) => (a.museum_entry_id < b.museum_entry_id ? -1 : 1));
  return entries;
}

function getRecord(playerId, entryId) {
  if (!registry[playerId]) {
    return null;
  }
  return registry[playerId][entryId] || null;
}

function resetRegistry() {
  museumRecords = null;
  registry = {};
  if (config.museumRegistryPath && fs.existsSync(config.museumRegistryPath)) {
    fs.rmSync(config.museumRegistryPath, { force: true });
  }
}

module.exports = {
  recordDiscovery,
  listRecords,
  getRecord,
  generateMuseumEntryId,
  resetRegistry,
};
