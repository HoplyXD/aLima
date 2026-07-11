const request = require('supertest');
const createApp = require('../src/app');
const { resetRegistry } = require('../src/services/museum_registry');

const app = createApp();

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

describe('mock-portal POST /museum', () => {
  beforeEach(() => {
    resetRegistry();
  });

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
  beforeEach(() => {
    resetRegistry();
  });

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
