const path = require('path');
require('dotenv').config();

function asInt(value, fallback) {
  const parsed = parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function asString(value, fallback) {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

// Test seam: the negotiate suite overrides the provider at runtime.
let _llmProviderOverride = null;

const config = {
  get port() { return asInt(process.env.PORT, 3000); },
  get portalBaseUrl() { return asString(process.env.PORTAL_BASE_URL, 'http://localhost:3001'); },
  get portalTimeoutMs() { return asInt(process.env.PORTAL_TIMEOUT_MS, 5000); },
  get portalApiKeyName() { return asString(process.env.PORTAL_API_KEY_NAME, 'Authorization'); },
  get portalApiKey() { return asString(process.env.PORTAL_API_KEY, ''); },
  get scanCachePath() {
    return asString(
      process.env.SCAN_CACHE_PATH,
      path.join(__dirname, '..', 'data', 'scanner_cache.json')
    );
  },
  get portalCachePath() {
    return asString(
      process.env.PORTAL_CACHE_PATH,
      path.join(__dirname, '..', 'cache', 'portal_cache.json')
    );
  },
  get museumCachePath() {
    return asString(
      process.env.MUSEUM_CACHE_PATH,
      path.join(__dirname, '..', 'cache', 'museum_cache.json')
    );
  },
  get rateLimitScan() { return asInt(process.env.RATE_LIMIT_SCAN, 30); },
  get rateLimitPortal() { return asInt(process.env.RATE_LIMIT_PORTAL, 10); },
  get rateLimitMuseum() { return asInt(process.env.RATE_LIMIT_MUSEUM, 20); },
  get rateLimitNegotiate() { return asInt(process.env.RATE_LIMIT_NEGOTIATE, 20); },
  // LLM buyer banter (MKT-R3). When no provider is usable the endpoint returns a
  // deterministic fallback so the exhibit never depends on a live model.
  // llmProvider: 'anthropic' (cloud Claude, needs a paid key), 'local' (a local
  // OpenAI-compatible server like Ollama — free + offline), or 'auto' (local when no
  // Anthropic key is set, else Anthropic).
  get llmProvider() {
    return _llmProviderOverride !== null ? _llmProviderOverride : asString(process.env.LLM_PROVIDER, 'anthropic');
  },
  set llmProvider(value) { _llmProviderOverride = value; },
  get anthropicApiKey() { return asString(process.env.ANTHROPIC_API_KEY, ''); },
  get anthropicModel() { return asString(process.env.ANTHROPIC_MODEL, 'claude-opus-4-8'); },
  // Local LLM (Ollama default). Run `ollama run llama3.2`, then set LLM_PROVIDER=local.
  get localLlmUrl() { return asString(process.env.LOCAL_LLM_URL, 'http://localhost:11434/v1/chat/completions'); },
  get localLlmModel() { return asString(process.env.LOCAL_LLM_MODEL, 'llama3.2'); },
  get localLlmApiKey() { return asString(process.env.LOCAL_LLM_API_KEY, 'ollama'); },
  get nodeEnv() { return asString(process.env.NODE_ENV, 'development'); },
};

module.exports = config;
