const request = require('supertest');
const createApp = require('../src/app');
const { resetCache } = require('../src/services/scan_service');

const app = createApp();

beforeEach(() => {
  resetCache();
});

describe('POST /api/scan', () => {
  test('returns cached fixture for tarnished_pendant', async () => {
    const res = await request(app)
      .post('/api/scan')
      .send({
        request_id: 'scan_001',
        template_id: 'tarnished_pendant',
        condition: 100,
        materials: ['silver'],
        markings: [],
        weight: 50,
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.request_id).toBe('scan_001');
    expect(res.body.type).toBe('pendant');
    expect(res.body.period).toBe('early 20th century');
    expect(res.body.price_range).toEqual([120, 280]);
    expect(res.body.fallback).toBe(true);
  });

  test('returns 404 for unknown template', async () => {
    const res = await request(app)
      .post('/api/scan')
      .send({ template_id: 'unknown_template', condition: 50 });

    expect(res.statusCode).toBe(404);
    expect(res.body.ok).toBe(false);
  });

  test('returns 400 when template_id is missing', async () => {
    const res = await request(app)
      .post('/api/scan')
      .send({ condition: 50 });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  test('returns 400 for hidden truth fields', async () => {
    for (const field of ['is_carrier', 'fragment_id', 'contents', 'is_counterfeit_truth']) {
      const body = { template_id: 'tarnished_pendant', condition: 50 };
      body[field] = true;
      const res = await request(app).post('/api/scan').send(body);
      expect(res.statusCode).toBe(400);
      expect(res.body.error).toContain(field);
    }
  });

  test('returns 400 when condition is out of range', async () => {
    const res = await request(app)
      .post('/api/scan')
      .send({ template_id: 'tarnished_pendant', condition: 150 });

    expect(res.statusCode).toBe(400);
    expect(res.body.ok).toBe(false);
  });
});
