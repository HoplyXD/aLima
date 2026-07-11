/**
 * Museum record + retrieval service (P16.4, MUS-R1..R3, PORT-R6).
 *
 * Extends the Phase 8 Portal proxy pattern (idempotency key, in-memory + disk
 * cache, timeout-bounded upstream call, deterministic fallback) from
 * portal_service.js to the museum endpoints:
 *
 *   recordDiscovery(body)      — POST /api/portal/museum (Gold finds + Master Artifact)
 *   listRecords(playerId)      — GET  /api/portal/museum?player_id=...
 *   getRecord(playerId, entry) — GET  /api/portal/museum/:entry_id?player_id=...
 *
 * The disk cache doubles as the offline retrieval store: every record this
 * server produces (upstream or fallback) is persisted keyed by
 * `player_id:record_id`, so the in-game gallery can hydrate from the Portal
 * when it is reachable and from these cached records when it is not (MUS-R3,
 * Invariant §4-O). Fallback fact text is deterministic and always marked
 * source-verification-pending — AI output is never a source of fact (§4-L).
 */

const fs = require('fs');
const http = require('http');
const https = require('https');
const { URL } = require('url');
const path = require('path');

const DEFAULT_FALLBACK_FACTS_PATH = path.join(
  __dirname,
  '..',
  '..',
  'data',
  'museum_fallback_facts.json'
);

let inMemoryCache = new Map();
let fallbackFacts = null;

function getCachePath() {
  return (
    process.env.MUSEUM_CACHE_PATH || path.join(__dirname, '..', '..', 'cache', 'museum_cache.json')
  );
}

function ensureCacheDir() {
  const dir = path.dirname(getCachePath());
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function loadDiskCache() {
  ensureCacheDir();
  if (!fs.existsSync(getCachePath())) {
    return {};
  }
  try {
    const raw = fs.readFileSync(getCachePath(), 'utf8');
    return JSON.parse(raw);
  } catch (_err) {
    return {};
  }
}

function saveDiskCache(cache) {
  ensureCacheDir();
  fs.writeFileSync(getCachePath(), JSON.stringify(cache, null, 2));
}

function getIdempotencyKey(playerId, recordId) {
  return `${playerId}:${recordId}`;
}

function generateMuseumEntryId(recordId, playerId) {
  return `entry_${recordId}_${playerId}`;
}

function loadFallbackFacts() {
  if (fallbackFacts) {
    return fallbackFacts;
  }
  const factsPath = process.env.MUSEUM_FALLBACK_FACTS_PATH || DEFAULT_FALLBACK_FACTS_PATH;
  if (!fs.existsSync(factsPath)) {
    fallbackFacts = {};
    return fallbackFacts;
  }
  const raw = fs.readFileSync(factsPath, 'utf8');
  fallbackFacts = JSON.parse(raw);
  return fallbackFacts;
}

function recordTypeForRarity(rarity) {
  return rarity === 'master_artifact' ? 'assembled_artifact' : 'museum_discovery';
}

/**
 * Deterministic offline record for a Gold find / Master Artifact. Text is
 * marked source-verification-pending; the real history is authored later from
 * verified sources (data/museum/, docs/sources/) — never from AI output (§4-L).
 */
function generateFallbackRecord(body) {
  const { record_id: recordId, player_id: playerId } = body;
  const rarity = body.rarity || 'gold';
  const facts = loadFallbackFacts();
  const fact = facts[recordId] || {
    fact_card:
      `A ${rarity === 'master_artifact' ? 'master artifact' : 'Gold-tier find'} ` +
      `(${recordId}). Its verified provenance record is pending — source ` +
      `verification is required before this text becomes a museum fact.`,
    timeline_entry: 'Provenance timeline pending source verification.',
    regional_story: 'Regional story pending source verification.',
    artifact_meta: {
      name: body.display_name || recordId,
      period: 'pending verification',
      origin: 'Western Visayas (pending verification)',
    },
  };

  return {
    ok: true,
    museum_entry_id: generateMuseumEntryId(recordId, playerId),
    record_id: recordId,
    record_type: recordTypeForRarity(rarity),
    fact_card: fact.fact_card,
    photo_ref: fact.photo_ref || '',
    timeline_entry: fact.timeline_entry || '',
    regional_story: fact.regional_story || '',
    character_memory_refs: fact.character_memory_refs || [],
    artifact_meta: fact.artifact_meta || {},
    used_fallback: true,
  };
}

function normalizeUpstreamRecord(body, upstream) {
  const { record_id: recordId, player_id: playerId } = body;
  return {
    ok: true,
    museum_entry_id: upstream.museum_entry_id || generateMuseumEntryId(recordId, playerId),
    record_id: upstream.record_id || recordId,
    record_type: upstream.record_type || recordTypeForRarity(body.rarity || 'gold'),
    fact_card: upstream.fact_card || '',
    photo_ref: upstream.photo_ref || '',
    timeline_entry: upstream.timeline_entry || '',
    regional_story: upstream.regional_story || '',
    character_memory_refs: Array.isArray(upstream.character_memory_refs)
      ? upstream.character_memory_refs
      : [],
    artifact_meta: upstream.artifact_meta || {},
    used_fallback: false,
  };
}

function getCachedResponse(key) {
  if (inMemoryCache.has(key)) {
    return inMemoryCache.get(key);
  }
  const disk = loadDiskCache();
  if (disk[key]) {
    inMemoryCache.set(key, disk[key]);
    return disk[key];
  }
  return null;
}

function setCachedResponse(key, response) {
  inMemoryCache.set(key, response);
  const disk = loadDiskCache();
  disk[key] = response;
  saveDiskCache(disk);
}

function getTimeoutMs() {
  return parseInt(process.env.PORTAL_TIMEOUT_MS || '5000', 10);
}

function proxyPostToPortal(urlPath, body) {
  return new Promise((resolve, reject) => {
    const baseUrl = process.env.PORTAL_BASE_URL || 'http://localhost:3001';
    const url = new URL(urlPath, baseUrl);
    const client = url.protocol === 'https:' ? https : http;
    const postData = JSON.stringify(body);

    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
      timeout: getTimeoutMs(),
    };

    const req = client.request(options, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (err) {
          reject(new Error(`Malformed upstream response: ${err.message}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Portal request timed out'));
    });

    req.write(postData);
    req.end();
  });
}

function proxyGetFromPortal(urlPathAndQuery) {
  return new Promise((resolve, reject) => {
    const baseUrl = process.env.PORTAL_BASE_URL || 'http://localhost:3001';
    const url = new URL(urlPathAndQuery, baseUrl);
    const client = url.protocol === 'https:' ? https : http;

    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: `${url.pathname}${url.search}`,
      method: 'GET',
      timeout: getTimeoutMs(),
    };

    const req = client.request(options, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (err) {
          reject(new Error(`Malformed upstream response: ${err.message}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Portal request timed out'));
    });

    req.end();
  });
}

/**
 * Records a museum discovery for a Gold find or the Master Artifact.
 * Idempotent per player_id:record_id — a repeat call returns the cached record
 * with the same museum_entry_id (duplicate prevention, DISP-R5/MUS-R2).
 */
async function recordDiscovery(body) {
  const { record_id: recordId, player_id: playerId } = body;
  const key = getIdempotencyKey(playerId, recordId);

  const cached = getCachedResponse(key);
  if (cached) {
    return cached;
  }

  try {
    const upstream = await proxyPostToPortal('/museum', body);

    if (upstream.status >= 400) {
      // Upstream client errors degrade to a deterministic local record so the
      // disposition flow always completes (ARCH-R2 / §4-O).
      const fallback = generateFallbackRecord(body);
      setCachedResponse(key, fallback);
      return fallback;
    }

    const result = normalizeUpstreamRecord(body, upstream.body);
    setCachedResponse(key, result);
    return result;
  } catch (_err) {
    const fallback = generateFallbackRecord(body);
    setCachedResponse(key, fallback);
    return fallback;
  }
}

function cachedRecordsForPlayer(playerId) {
  const disk = loadDiskCache();
  const entries = [];
  for (const key of Object.keys(disk)) {
    const record = disk[key];
    if (record && record.museum_entry_id && key.startsWith(`${playerId}:`)) {
      entries.push(record);
    }
  }
  entries.sort((a, b) => (a.museum_entry_id < b.museum_entry_id ? -1 : 1));
  return entries;
}

/**
 * Lists museum records for a player. Tries the upstream Portal first; on
 * success the entries are merged into the disk cache (so later offline lists
 * include them) and returned with used_fallback: false. On timeout/network
 * failure/malformed upstream, returns the cached records with
 * used_fallback: true — the gallery stays usable offline (MUS-R3, §4-O).
 */
async function listRecords(playerId) {
  try {
    const upstream = await proxyGetFromPortal(
      `/museum?player_id=${encodeURIComponent(playerId)}`
    );

    if (upstream.status >= 400) {
      return { ok: true, entries: cachedRecordsForPlayer(playerId), used_fallback: true };
    }

    const entries = Array.isArray(upstream.body.entries) ? upstream.body.entries : [];
    for (const entry of entries) {
      if (entry && entry.record_id) {
        setCachedResponse(getIdempotencyKey(playerId, entry.record_id), entry);
      }
    }
    return { ok: true, entries, used_fallback: false };
  } catch (_err) {
    return { ok: true, entries: cachedRecordsForPlayer(playerId), used_fallback: true };
  }
}

/**
 * Retrieves one museum record by entry id. Upstream first, then the disk
 * cache; null when neither has it (the route maps null to a 404).
 */
async function getRecord(playerId, entryId) {
  try {
    const upstream = await proxyGetFromPortal(
      `/museum/${encodeURIComponent(entryId)}?player_id=${encodeURIComponent(playerId)}`
    );

    if (upstream.status === 404) {
      return null;
    }
    if (upstream.status >= 400) {
      return cachedRecordByEntryId(playerId, entryId);
    }

    const record = upstream.body;
    if (record && record.record_id) {
      setCachedResponse(getIdempotencyKey(playerId, record.record_id), record);
    }
    return record;
  } catch (_err) {
    return cachedRecordByEntryId(playerId, entryId);
  }
}

function cachedRecordByEntryId(playerId, entryId) {
  const disk = loadDiskCache();
  for (const key of Object.keys(disk)) {
    const record = disk[key];
    if (
      record &&
      key.startsWith(`${playerId}:`) &&
      record.museum_entry_id === entryId
    ) {
      return record;
    }
  }
  return null;
}

function resetCache() {
  inMemoryCache = new Map();
  fallbackFacts = null;
  if (fs.existsSync(getCachePath())) {
    fs.rmSync(getCachePath(), { force: true });
  }
}

module.exports = {
  recordDiscovery,
  listRecords,
  getRecord,
  generateMuseumEntryId,
  getIdempotencyKey,
  generateFallbackRecord,
  resetCache,
};
