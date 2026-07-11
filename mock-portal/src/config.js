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
  port: asInt(process.env.PORT, 3001),
  factCardsPath: asString(
    process.env.FACT_CARDS_PATH,
    path.join(__dirname, '..', 'data', 'fact_cards.json')
  ),
  museumRecordsPath: asString(
    process.env.MUSEUM_RECORDS_PATH,
    path.join(__dirname, '..', 'data', 'museum_records.json')
  ),
  museumRegistryPath: asString(
    process.env.MUSEUM_REGISTRY_PATH,
    path.join(__dirname, '..', 'cache', 'museum_registry.json')
  ),
  nodeEnv: asString(process.env.NODE_ENV, 'development'),
};

module.exports = config;
