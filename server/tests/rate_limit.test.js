const request = require('supertest');
const createApp = require('../src/app');

describe('Rate limiting', () => {
  const originalScanLimit = process.env.RATE_LIMIT_SCAN;
  const originalPortalLimit = process.env.RATE_LIMIT_PORTAL;
  const originalNegotiateLimit = process.env.RATE_LIMIT_NEGOTIATE;

  beforeAll(() => {
    process.env.RATE_LIMIT_SCAN = '2';
    process.env.RATE_LIMIT_PORTAL = '2';
    process.env.RATE_LIMIT_NEGOTIATE = '2';
  });

  afterAll(() => {
    process.env.RATE_LIMIT_SCAN = originalScanLimit;
    process.env.RATE_LIMIT_PORTAL = originalPortalLimit;
    process.env.RATE_LIMIT_NEGOTIATE = originalNegotiateLimit;
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

  test('portal discovery endpoint returns 429 after exceeding limit', async () => {
    const app = createApp();
    const body = {
      artifact_id: 'master_artifact_demo',
      fragment_id: 'fragment_01',
      player_id: 'rate-limit-player',
      timestamp: '2026-06-16T22:46:58Z',
      condition: 100,
    };

    const first = await request(app).post('/api/portal/discovery').send(body);
    expect(first.statusCode).toBe(200);

    const second = await request(app).post('/api/portal/discovery').send(body);
    expect(second.statusCode).toBe(200);

    const third = await request(app).post('/api/portal/discovery').send(body);
    expect(third.statusCode).toBe(429);
    expect(third.body.ok).toBe(false);
    expect(third.body.error).toMatch(/Too many portal requests/i);
  });

  test('negotiate endpoint returns 429 after exceeding limit', async () => {
    const app = createApp();
    const body = {
      persona: {
        id: 'collector',
        display_name: 'Doña Esperanza',
        motive: 'Completes a private collection.',
        negotiation_style: 'appraising',
      },
      listing_price: 250,
      player_message: 'This piece has real history behind it.',
      history: [],
    };

    const first = await request(app).post('/api/negotiate').send(body);
    expect(first.statusCode).toBe(200);

    const second = await request(app).post('/api/negotiate').send(body);
    expect(second.statusCode).toBe(200);

    const third = await request(app).post('/api/negotiate').send(body);
    expect(third.statusCode).toBe(429);
    expect(third.body.ok).toBe(false);
    expect(third.body.error).toMatch(/Too many negotiation requests/i);
  });
});
