const request = require('supertest');
const createApp = require('../src/app');
const { resetClient } = require('../src/services/negotiate_service');

// These tests run with no ANTHROPIC_API_KEY, so the endpoint takes the deterministic
// fallback path (no live model, no @anthropic-ai/sdk dependency required).
describe('POST /api/negotiate', () => {
  const app = createApp();

  beforeEach(() => {
    delete process.env.ANTHROPIC_API_KEY;
    resetClient();
  });

  const validBody = {
    persona: {
      id: 'collector',
      display_name: 'Doña Esperanza',
      motive: 'Completes a private collection.',
      negotiation_style: 'appraising',
    },
    listing_price: 250,
    player_message: 'This piece has real history behind it.',
    history: [{ role: 'buyer', text: 'A fine piece. I could give you ₱150.' }],
  };

  it('returns a fallback banter response when no API key is configured', async () => {
    const res = await request(app).post('/api/negotiate').send(validBody);
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.fallback).toBe(true);
    expect(res.body.offer).toBe(250);
    expect(res.body.walked_away).toBe(false);
  });

  it('rejects a request with no persona', async () => {
    const res = await request(app).post('/api/negotiate').send({ listing_price: 100 });
    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  it('rejects a persona without a display_name', async () => {
    const res = await request(app)
      .post('/api/negotiate')
      .send({ persona: { id: 'x' }, listing_price: 100 });
    expect(res.status).toBe(400);
  });

  it('rejects a non-array history', async () => {
    const res = await request(app)
      .post('/api/negotiate')
      .send({ ...validBody, history: 'nope' });
    expect(res.status).toBe(400);
  });
});
