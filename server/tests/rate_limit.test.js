const request = require('supertest');
const createApp = require('../src/app');

describe('Rate limiting', () => {
  const originalScanLimit = process.env.RATE_LIMIT_SCAN;
  const originalPortalLimit = process.env.RATE_LIMIT_PORTAL;

  beforeAll(() => {
    process.env.RATE_LIMIT_SCAN = '2';
    process.env.RATE_LIMIT_PORTAL = '2';
  });

  afterAll(() => {
    process.env.RATE_LIMIT_SCAN = originalScanLimit;
    process.env.RATE_LIMIT_PORTAL = originalPortalLimit;
  });

  test('scan endpoint returns 429 after exceeding limit', async () => {
    // Re-create app so rate limiter picks up the new env values.
    const app = createApp();
    const body = { template_id: 'tarnished_pendant', condition: 50 };

    const first = await request(app).post('/api/scan').send(body);
    expect(first.statusCode).toBe(200);

    const second = await request(app).post('/api/scan').send(body);
    expect(second.statusCode).toBe(200);

    const third = await request(app).post('/api/scan').send(body);
    expect(third.statusCode).toBe(429);
    expect(third.body.ok).toBe(false);
  });
});
