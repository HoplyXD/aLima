const fs = require('fs');
const path = require('path');
const request = require('supertest');
const { initApp } = require('../src/app');
const { resetRegistry } = require('../src/services/museum_registry');
const db = require('../src/db');

let app;

const GOLD_RECORD = {
  record_id: 'oton_death_mask',
  player_id: 'local-player',
  rarity: 'gold',
  timestamp: '2026-07-11T12:00:00Z',
  condition: 95,
  discovery_context: 'preserved from shop inventory',
  display_name: 'Oton Death Mask',
};

const MASTER_RECORD = {
  record_id: 'master_artifact_demo',
  player_id: 'local-player',
  rarity: 'master_artifact',
  timestamp: '2026-07-11T12:00:00Z',
  condition: 100,
  discovery_context: 'assembled from five seated fragments',
  display_name: 'Heirloom Timepiece (placeholder)',
};

beforeAll(async () => {
  app = await initApp();
});

afterAll(async () => {
  await db.close();
});

beforeEach(async () => {
  await resetRegistry();
});

describe('mock-portal POST /museum', () => {
  test('records a Gold discovery deterministically', async () => {
    const res = await request(app).post('/museum').send(GOLD_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_oton_death_mask_local-player');
    expect(res.body.record_type).toBe('museum_discovery');
    expect(res.body.fact_card).toContain('SOURCE VERIFICATION PENDING');
  });

  test('records a Master Artifact as assembled_artifact', async () => {
    const res = await request(app).post('/museum').send(MASTER_RECORD);

    expect(res.statusCode).toBe(200);
    expect(res.body.record_type).toBe('assembled_artifact');
    expect(res.body.museum_entry_id).toBe('entry_master_artifact_demo_local-player');
  });

  test('duplicate post returns same entry id', async () => {
    await request(app).post('/museum').send(GOLD_RECORD);
    const res = await request(app).post('/museum').send(GOLD_RECORD);

    expect(res.body.museum_entry_id).toBe('entry_oton_death_mask_local-player');
  });

  test('invalid payload returns 400', async () => {
    const res = await request(app).post('/museum').send({ record_id: 'x' });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });
});

describe('mock-portal GET /museum', () => {
  test('lists recorded entries for a player', async () => {
    await request(app).post('/museum').send(GOLD_RECORD);
    await request(app).post('/museum').send(MASTER_RECORD);

    const res = await request(app)
      .get('/museum')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.entries.length).toBe(2);
    const ids = res.body.entries.map((e) => e.museum_entry_id);
    expect(ids).toContain('entry_oton_death_mask_local-player');
    expect(ids).toContain('entry_master_artifact_demo_local-player');
  });

  test('returns one entry by id', async () => {
    await request(app).post('/museum').send(GOLD_RECORD);

    const res = await request(app)
      .get('/museum/entry_oton_death_mask_local-player')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(200);
    expect(res.body.record_id).toBe('oton_death_mask');
  });

  test('unknown entry returns 404', async () => {
    const res = await request(app)
      .get('/museum/entry_no_such_id_local-player')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(404);
    expect(res.body.ok).toBe(false);
  });
});

describe('mock-portal API-key auth', () => {
  let authApp;
  const TEST_KEY = 'portal-test-key';
  let originalKey;

  beforeAll(async () => {
    originalKey = process.env.PORTAL_API_KEY;
    process.env.PORTAL_API_KEY = TEST_KEY;
    authApp = await initApp();
  });

  afterAll(async () => {
    if (originalKey) {
      process.env.PORTAL_API_KEY = originalKey;
    } else {
      delete process.env.PORTAL_API_KEY;
    }
    await db.close();
  });

  beforeEach(async () => {
    await resetRegistry();
  });

  test('rejects requests with no Authorization header', async () => {
    const res = await request(authApp).post('/museum').send(GOLD_RECORD);

    expect(res.statusCode).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  test('rejects a wrong Bearer token', async () => {
    const res = await request(authApp)
      .post('/museum')
      .send(GOLD_RECORD)
      .set('Authorization', 'Bearer wrong-key');

    expect(res.statusCode).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  test('accepts the configured Bearer token', async () => {
    const res = await request(authApp)
      .post('/museum')
      .send(GOLD_RECORD)
      .set('Authorization', `Bearer ${TEST_KEY}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_oton_death_mask_local-player');
  });
});

describe('mock-portal restart persistence', () => {
  const dbPath = path.join(__dirname, '..', 'cache', 'test_restart.db');
  let originalDbPath;

  beforeAll(() => {
    originalDbPath = process.env.DATABASE_PATH;
    process.env.DATABASE_PATH = dbPath;
    delete process.env.PORTAL_API_KEY;
    if (fs.existsSync(dbPath)) {
      fs.unlinkSync(dbPath);
    }
  });

  afterAll(async () => {
    process.env.DATABASE_PATH = originalDbPath;
    await db.close();
    if (fs.existsSync(dbPath)) {
      fs.unlinkSync(dbPath);
    }
  });

  beforeEach(async () => {
    await resetRegistry();
  });

  test('records survive an app restart', async () => {
    const firstApp = await initApp();
    const post = await request(firstApp).post('/museum').send(GOLD_RECORD);

    expect(post.statusCode).toBe(200);
    expect(post.body.museum_entry_id).toBe('entry_oton_death_mask_local-player');

    await db.close();

    const secondApp = await initApp();
    const res = await request(secondApp)
      .get('/museum')
      .query({ player_id: 'local-player' });

    expect(res.statusCode).toBe(200);
    expect(res.body.entries.length).toBe(1);
    expect(res.body.entries[0].museum_entry_id).toBe('entry_oton_death_mask_local-player');
  });
});
