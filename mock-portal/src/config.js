const path = require('path');
require('dotenv').config();

function asInt(value, fallback) {
  const parsed = parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function asString(value, fallback) {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

function asBool(value) {
  return value === 'true' || value === '1';
}

const config = {
  get port() { return asInt(process.env.PORT, 3001); },
  get portalApiKey() { return asString(process.env.PORTAL_API_KEY, ''); },
  get requireApiKey() { return asBool(process.env.PORTAL_REQUIRE_API_KEY); },
  get databasePath() {
    return asString(
      process.env.DATABASE_PATH,
      path.join(__dirname, '..', 'cache', 'portal.db')
    );
  },
  get factCardsPath() {
    return asString(
      process.env.FACT_CARDS_PATH,
      path.join(__dirname, '..', 'data', 'fact_cards.json')
    );
  },
  get museumRecordsPath() {
    return asString(
      process.env.MUSEUM_RECORDS_PATH,
      path.join(__dirname, '..', 'data', 'museum_records.json')
    );
  },
  get nodeEnv() { return asString(process.env.NODE_ENV, 'development'); },
};

module.exports = config;
