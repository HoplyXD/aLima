const request = require('supertest');
const createApp = require('../src/app');
const { resetCache } = require('../src/services/fact_service');

const app = createApp();

describe('POST /discovery', () => {
  beforeEach(() => {
    resetCache();
  });

  test('known fragment returns deterministic fact card', async () => {
    const res = await request(app)
      .post('/discovery')
      .send({
        artifact_id: 'master_artifact_demo',
        fragment_id: 'fragment_01',
        player_id: 'local-player',
        timestamp: '2026-06-16T22:46:58Z',
        condition: 100,
        discovery_context: 'test',
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.museum_entry_id).toBe('entry_fragment_01_local-player');
    expect(res.body.fragment_index).toBe(1);
    expect(res.body.fact_card).toContain('gear');
    expect(res.body.artifact_meta).toMatchObject({
      name: 'Heirloom Timepiece Gear',
      period: 'early 20th century',
      origin: 'Western Visayas',
    });
  });

  test('unknown fragment returns 404', async () => {
    const res = await request(app)
      .post('/discovery')
      .send({
        artifact_id: 'master_artifact_demo',
        fragment_id: 'fragment_99',
        player_id: 'local-player',
        timestamp: '2026-06-16T22:46:58Z',
        condition: 100,
      });

    expect(res.statusCode).toBe(404);
    expect(res.body.ok).toBe(false);
  });

  test('invalid payload returns 400', async () => {
    const res = await request(app)
      .post('/discovery')
      .send({ fragment_id: 'fragment_01' });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  test('repeated request returns same museum_entry_id', async () => {
    const body = {
      artifact_id: 'master_artifact_demo',
      fragment_id: 'fragment_03',
      player_id: 'local-player',
      timestamp: '2026-06-16T22:46:58Z',
      condition: 85,
      discovery_context: 'repeat test',
    };

    const first = await request(app).post('/discovery').send(body);
    const second = await request(app).post('/discovery').send(body);

    expect(first.body.museum_entry_id).toBe(second.body.museum_entry_id);
    expect(first.body.fact_card).toBe(second.body.fact_card);
  });
});
