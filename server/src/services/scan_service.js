const fs = require('fs');
const config = require('../config');

let cacheEntries = null;

function loadCache() {
  if (cacheEntries) {
    return cacheEntries;
  }
  const raw = fs.readFileSync(config.scanCachePath, 'utf8');
  const parsed = JSON.parse(raw);
  if (!parsed || !Array.isArray(parsed.items)) {
    throw new Error('Invalid scanner cache format');
  }
  cacheEntries = new Map(parsed.items.map((item) => [item.template_id, item]));
  return cacheEntries;
}

/**
 * Returns a cached scanner response for the given template_id.
 *
 * The response is advisory only and never reveals carrier/counterfeit truth.
 */
function getCachedResponse(templateId, requestId) {
  const cache = loadCache();
  const entry = cache.get(templateId);
  if (!entry) {
    const err = new Error(`No cached response for template '${templateId}'`);
    err.statusCode = 404;
    throw err;
  }

  const response = JSON.parse(JSON.stringify(entry.response));
  response.ok = true;
  response.request_id = requestId || '';
  response.fallback = entry.fallback === true;
  return response;
}

function resetCache() {
  cacheEntries = null;
}

module.exports = {
  loadCache,
  getCachedResponse,
  resetCache,
};
