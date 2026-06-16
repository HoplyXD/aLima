const fs = require('fs');
const http = require('http');
const https = require('https');
const { URL } = require('url');
const path = require('path');

const DEFAULT_FALLBACK_FACTS_PATH = path.join(__dirname, '..', '..', 'data', 'fallback_facts.json');

let inMemoryCache = new Map();
let fallbackFacts = null;

function getCachePath() {
  return process.env.PORTAL_CACHE_PATH || path.join(__dirname, '..', '..', 'cache', 'portal_cache.json');
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

function getIdempotencyKey(playerId, fragmentId) {
  return `${playerId}:${fragmentId}`;
}

function generateMuseumEntryId(fragmentId, playerId) {
  return `entry_${fragmentId}_${playerId}`;
}

function loadFallbackFacts() {
  if (fallbackFacts) {
    return fallbackFacts;
  }
  const factsPath = process.env.FALLBACK_FACTS_PATH || DEFAULT_FALLBACK_FACTS_PATH;
  if (!fs.existsSync(factsPath)) {
    fallbackFacts = {};
    return fallbackFacts;
  }
  const raw = fs.readFileSync(factsPath, 'utf8');
  fallbackFacts = JSON.parse(raw);
  return fallbackFacts;
}

function generateFallback(fragmentId, playerId) {
  const facts = loadFallbackFacts();
  const fact = facts[fragmentId] || {
    fragment_index: 0,
    fact_card: `A recovered fragment (${fragmentId}). Its full provenance awaits verification.`,
    artifact_meta: {
      name: 'Unknown Fragment',
      period: 'unknown',
      origin: 'unknown',
    },
  };

  return {
    ok: true,
    museum_entry_id: generateMuseumEntryId(fragmentId, playerId),
    fragment_index: fact.fragment_index,
    fact_card: fact.fact_card,
    artifact_meta: fact.artifact_meta,
    used_fallback: true,
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

function proxyToPortal(body) {
  return new Promise((resolve, reject) => {
    const baseUrl = process.env.PORTAL_BASE_URL || 'http://localhost:3001';
    const url = new URL('/discovery', baseUrl);
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
      timeout: parseInt(process.env.PORTAL_TIMEOUT_MS || '5000', 10),
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

async function discover(body) {
  const { fragment_id: fragmentId, player_id: playerId } = body;
  const key = getIdempotencyKey(playerId, fragmentId);

  const cached = getCachedResponse(key);
  if (cached) {
    return cached;
  }

  try {
    const upstream = await proxyToPortal(body);

    if (upstream.status >= 400) {
      // Treat upstream client errors as deterministic fallback so the game can continue.
      const fallback = generateFallback(fragmentId, playerId);
      setCachedResponse(key, fallback);
      return fallback;
    }

    const result = {
      ok: true,
      museum_entry_id: upstream.body.museum_entry_id || generateMuseumEntryId(fragmentId, playerId),
      fragment_index: upstream.body.fragment_index || 0,
      fact_card: upstream.body.fact_card || '',
      artifact_meta: upstream.body.artifact_meta || {},
      used_fallback: false,
    };

    setCachedResponse(key, result);
    return result;
  } catch (_err) {
    const fallback = generateFallback(fragmentId, playerId);
    setCachedResponse(key, fallback);
    return fallback;
  }
}

function resetCache() {
  inMemoryCache = new Map();
  fallbackFacts = null;
  if (fs.existsSync(getCachePath())) {
    fs.rmSync(getCachePath(), { force: true });
  }
}

module.exports = {
  discover,
  generateMuseumEntryId,
  getIdempotencyKey,
  generateFallback,
  resetCache,
};
