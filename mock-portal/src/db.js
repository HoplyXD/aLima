const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const config = require('./config');

let db = null;

function ensureDir(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function getDb() {
  if (db) {
    return db;
  }
  ensureDir(config.databasePath);
  db = new sqlite3.Database(config.databasePath);
  return db;
}

function init() {
  return new Promise((resolve, reject) => {
    const database = getDb();
    database.run(
      `CREATE TABLE IF NOT EXISTS museum_records (
        player_id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        record_id TEXT NOT NULL,
        record_type TEXT NOT NULL,
        rarity TEXT NOT NULL,
        display_name TEXT NOT NULL DEFAULT '',
        fact_card TEXT NOT NULL DEFAULT '',
        photo_ref TEXT NOT NULL DEFAULT '',
        timeline_entry TEXT NOT NULL DEFAULT '',
        regional_story TEXT NOT NULL DEFAULT '',
        character_memory_refs TEXT NOT NULL DEFAULT '[]',
        artifact_meta TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        PRIMARY KEY (player_id, entry_id)
      )`,
      (err) => {
        if (err) {
          reject(err);
          return;
        }
        database.run(
          'CREATE INDEX IF NOT EXISTS idx_museum_records_player ON museum_records(player_id)',
          (idxErr) => {
            if (idxErr) {
              reject(idxErr);
              return;
            }
            resolve();
          }
        );
      }
    );
  });
}

function rowToRecord(row) {
  return {
    ok: true,
    museum_entry_id: row.entry_id,
    record_id: row.record_id,
    record_type: row.record_type,
    rarity: row.rarity,
    display_name: row.display_name,
    fact_card: row.fact_card,
    photo_ref: row.photo_ref,
    timeline_entry: row.timeline_entry,
    regional_story: row.regional_story,
    character_memory_refs: JSON.parse(row.character_memory_refs),
    artifact_meta: JSON.parse(row.artifact_meta),
    created_at: row.created_at,
  };
}

function recordDiscovery(record) {
  return new Promise((resolve, reject) => {
    const database = getDb();
    const {
      player_id: playerId,
      entry_id: entryId,
      record_id: recordId,
      record_type: recordType,
      rarity,
      display_name: displayName,
      fact_card: factCard,
      photo_ref: photoRef,
      timeline_entry: timelineEntry,
      regional_story: regionalStory,
      character_memory_refs: characterMemoryRefs,
      artifact_meta: artifactMeta,
    } = record;

    database.run(
      `INSERT OR REPLACE INTO museum_records
        (player_id, entry_id, record_id, record_type, rarity, display_name,
         fact_card, photo_ref, timeline_entry, regional_story,
         character_memory_refs, artifact_meta, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        playerId,
        entryId,
        recordId,
        recordType,
        rarity,
        displayName,
        factCard,
        photoRef,
        timelineEntry,
        regionalStory,
        JSON.stringify(characterMemoryRefs || []),
        JSON.stringify(artifactMeta || {}),
        record.created_at || new Date().toISOString(),
      ],
      function (err) {
        if (err) {
          reject(err);
          return;
        }
        resolve(record);
      }
    );
  });
}

function listRecords(playerId) {
  return new Promise((resolve, reject) => {
    const database = getDb();
    database.all(
      'SELECT * FROM museum_records WHERE player_id = ? ORDER BY created_at ASC, entry_id ASC',
      [playerId],
      (err, rows) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(rows.map(rowToRecord));
      }
    );
  });
}

function getRecord(playerId, entryId) {
  return new Promise((resolve, reject) => {
    const database = getDb();
    database.get(
      'SELECT * FROM museum_records WHERE player_id = ? AND entry_id = ?',
      [playerId, entryId],
      (err, row) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(row ? rowToRecord(row) : null);
      }
    );
  });
}

function resetRecords() {
  return new Promise((resolve, reject) => {
    const database = getDb();
    database.run('DELETE FROM museum_records', (err) => {
      if (err) {
        // Tolerate a missing table during tests that reset before init().
        if (err.message && err.message.includes('no such table')) {
          resolve();
          return;
        }
        reject(err);
        return;
      }
      resolve();
    });
  });
}

function close() {
  return new Promise((resolve) => {
    if (db) {
      db.close(() => {
        db = null;
        resolve();
      });
      return;
    }
    resolve();
  });
}

module.exports = {
  init,
  recordDiscovery,
  listRecords,
  getRecord,
  resetRecords,
  close,
};
