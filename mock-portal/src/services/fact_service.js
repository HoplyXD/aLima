const fs = require('fs');
const config = require('../config');

let factCards = null;

function loadFactCards() {
  if (factCards) {
    return factCards;
  }
  const raw = fs.readFileSync(config.factCardsPath, 'utf8');
  factCards = JSON.parse(raw);
  return factCards;
}

function generateMuseumEntryId(fragmentId, playerId) {
  return `entry_${fragmentId}_${playerId}`;
}

function getFactCard(fragmentId, playerId) {
  const cards = loadFactCards();
  const card = cards[fragmentId];
  if (!card) {
    const err = new Error(`Unknown fragment '${fragmentId}'`);
    err.statusCode = 404;
    throw err;
  }

  return {
    ok: true,
    museum_entry_id: generateMuseumEntryId(fragmentId, playerId),
    fragment_index: card.fragment_index,
    fact_card: card.fact_card,
    artifact_meta: card.artifact_meta,
  };
}

function resetCache() {
  factCards = null;
}

module.exports = {
  loadFactCards,
  getFactCard,
  generateMuseumEntryId,
  resetCache,
};
