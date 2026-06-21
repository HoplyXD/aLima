const request = require('supertest');
const createApp = require('../src/app');
const { resetClient, parseReply, generateBanter } = require('../src/services/negotiate_service');
const config = require('../src/config');

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

  it('returns offended:false on the fallback path', async () => {
    const res = await request(app).post('/api/negotiate').send(validBody);
    expect(res.body.offended).toBe(false);
  });

  it('rejects a non-array history', async () => {
    const res = await request(app)
      .post('/api/negotiate')
      .send({ ...validBody, history: 'nope' });
    expect(res.status).toBe(400);
  });
});

describe('negotiate parseReply', () => {
  it('parses a JSON reply with an offended verdict', () => {
    const out = parseReply('{"buyer_message": "Yuck, you\'re weird!", "offended": true}');
    expect(out.buyer_message).toBe("Yuck, you're weird!");
    expect(out.offended).toBe(true);
  });

  it('tolerates a code fence around the JSON', () => {
    const out = parseReply('```json\n{"buyer_message": "Fine. ₱200.", "offended": false}\n```');
    expect(out.buyer_message).toBe('Fine. ₱200.');
    expect(out.offended).toBe(false);
  });

  it('falls back to plain text (not offended) when the reply is not JSON', () => {
    const out = parseReply('A fine piece indeed.');
    expect(out.buyer_message).toBe('A fine piece indeed.');
    expect(out.offended).toBe(false);
  });
});

describe('local LLM provider', () => {
  const savedProvider = config.llmProvider;
  const body = {
    persona: { id: 'collector', display_name: 'Doña Esperanza', negotiation_style: 'appraising' },
    listing_price: 200,
    player_message: 'This has real history.',
    history: [],
  };

  afterEach(() => {
    config.llmProvider = savedProvider;
    delete global.fetch;
  });

  it('uses the local endpoint and parses its JSON reply', async () => {
    config.llmProvider = 'local';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        choices: [{ message: { content: '{"buyer_message":"Aba, maganda ito!","offended":false}' } }],
      }),
    });
    const res = await generateBanter(body);
    expect(global.fetch).toHaveBeenCalled();
    expect(res.fallback).toBe(false);
    expect(res.buyer_message).toBe('Aba, maganda ito!');
    expect(res.offended).toBe(false);
  });

  it('falls back when the local server is unreachable', async () => {
    config.llmProvider = 'local';
    global.fetch = jest.fn().mockRejectedValue(new Error('ECONNREFUSED'));
    const res = await generateBanter(body);
    expect(res.fallback).toBe(true);
  });
});
