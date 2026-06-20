const path = require('path');
require('dotenv').config();

function asInt(value, fallback) {
  const parsed = parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function asString(value, fallback) {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

const config = {
  port: asInt(process.env.PORT, 3000),
  portalBaseUrl: asString(process.env.PORTAL_BASE_URL, 'http://localhost:3001'),
  portalTimeoutMs: asInt(process.env.PORTAL_TIMEOUT_MS, 5000),
  scanCachePath: asString(
    process.env.SCAN_CACHE_PATH,
    path.join(__dirname, '..', 'data', 'scanner_cache.json')
  ),
  portalCachePath: asString(
    process.env.PORTAL_CACHE_PATH,
    path.join(__dirname, '..', 'cache', 'portal_cache.json')
  ),
  rateLimitScan: asInt(process.env.RATE_LIMIT_SCAN, 30),
  rateLimitPortal: asInt(process.env.RATE_LIMIT_PORTAL, 10),
  rateLimitNegotiate: asInt(process.env.RATE_LIMIT_NEGOTIATE, 20),
  // LLM buyer banter (MKT-R3). When the key is absent the endpoint returns a
  // deterministic fallback so the exhibit never depends on a live model.
  anthropicApiKey: asString(process.env.ANTHROPIC_API_KEY, ''),
  anthropicModel: asString(process.env.ANTHROPIC_MODEL, 'claude-opus-4-8'),
  nodeEnv: asString(process.env.NODE_ENV, 'development'),
};

module.exports = config;
